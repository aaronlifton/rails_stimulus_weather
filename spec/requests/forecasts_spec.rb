require "spec_helper"

RSpec.describe ForecastsController, type: :request do
  subject(:perform_request) { get("/forecasts", as: :json) }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:headers) {
    {
      "Accept" => "*/*",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Content-Type" => "application/json",
      "User-Agent" => "Ruby"
    }
  }
  let(:response_headers) {
    {
      "date" => ["Thu, 15 Jan 2026 00:33:50 GMT"],
      "content-type" => ["application/json; charset=utf-8"],
      "connection" => ["close"],
      "x-cache-key" => ["/geo/1.0/zipasdf?"],
      "access-control-allow-origin" => ["*"],
      "access-control-allow-credentials" => ["true"],
      "access-control-allow-methods" => ["GET, POST"]
    }
  }
  let(:weather_response_headers) {
    {
      "date" => ["Thu, 15 Jan 2026 22:34:53 GMT"],
      "content-type" => ["application/json"],
      "content-length" => ["701"],
      "connection" => ["close"],
      "x-frame-options" => ["DENY"],
      "cache-control" => ["private, no-store"],
      "strict-transport-security" => ["max-age=31536000"],
      "x-content-type-options" => ["nosniff"],
      "x-xss-protection" => ["1;mode=block"],
      "vary" => ["Origin"],
      "set-cookie" => [
        "TS0193e6a1=01283c52a4d29ddf99b16fb2ff97be5132f35a2c381d544d90bb9beed6598a44d26bb1daf0318aa19f038ac08bed0f9fe6148a3519; Path=/; Domain=.geocoding.geo.census.gov; Secure; HttpOnly"
      ]
    }
  }
  let(:zipcode) { "20233" }
  let(:address) { "4600 Silver Hill Rd, Washington, DC" }
  let(:lat) { 27.9004 }
  let(:lon) { -82.7152 }
  let(:temp) { 60.53 }
  let(:temp_min) { 58.14 }
  let(:temp_max) { 63.05 }
  let(:api_key) { "abc123" }

  it "renders a json error if address is missing" do
    perform_request

    expect(response.parsed_body).to(
      eq(
        {
          "error" => "address parameter is required",
          "code" => "address_required"
        }
      )
    )
  end

  before do
    allow(Rails).to(receive(:cache).and_return(memory_store))
    Rails.cache.clear
  end

  context("when address is present") do
    subject(:perform_request) { get("/forecasts", params: {address: address}, as: :json) }

    before do
      allow(Rails.application.credentials).to(receive(:open_weather_map_api_key).and_return(api_key))

      stub_request(:get, "#{GeocoderApi.base_uri}#{GeocoderApi::GEOLOCATION_PATH}")
        .with(
          query: {
            "address" => address,
            "benchmark" => GeocoderApi::DEFAULT_BENCHMARK,
            "format" => "json"
          },
          headers: headers
        )
        .to_return(
          {
            body: {
              "result" => {
                "input" => {
                  "address" => {
                    "address" => "4600 Silver Hill Rd, Washington, DC"
                  },
                  "benchmark" => {
                    "isDefault" => true,
                    "benchmarkDescription" => "Public Address Ranges - Current Benchmark",
                    "id" => "4",
                    "benchmarkName" => "Public_AR_Current"
                  }
                },
                "addressMatches" => [
                  {
                    "tigerLine" => {"side" => "L", "tigerLineId" => "76355984"},
                    "coordinates" => {"x" => lon, "y" => lat},
                    "addressComponents" => {
                      "zip" => zipcode,
                      "streetName" => "SILVER HILL",
                      "preType" => "",
                      "city" => "WASHINGTON",
                      "preDirection" => "",
                      "suffixDirection" => "",
                      "fromAddress" => "4600",
                      "state" => "DC",
                      "suffixType" => "RD",
                      "toAddress" => "4700",
                      "suffixQualifier" => "",
                      "preQualifier" => ""
                    },
                    "matchedAddress" => "4600 SILVER HILL RD, WASHINGTON, DC, 20233"
                  }
                ]
              }
            }.to_json,
            status: 200,
            headers: {}
          }
        )

      stub_request(:get, "#{WeatherApi.base_uri}#{WeatherApi::WEATHER_PATH}")
        .with(
          query: {
            "lat" => lat,
            "lon" => lon,
            "units" => "imperial",
            "exclude" => WeatherApi::DEFAULT_EXCLUDE,
            "appid" => api_key
          },
          headers: headers
        )
        .to_return(
          {
            body: {
              "coord" => {"lon" => 0, "lat" => 0},
              "weather" => [{"id" => 804, "main" => "Clouds", "description" => "overcast clouds", "icon" => "04n"}],
              "base" => "stations",
              "main" => {
                "temp" => temp,
                "feels_like" => temp,
                "temp_min" => temp_min,
                "temp_max" => temp_max,
                "pressure" => 1011,
                "humidity" => 81,
                "sea_level" => 1011,
                "grnd_level" => 1011
              },
              "visibility" => 10000,
              "wind" => {"speed" => 9.57, "deg" => 209, "gust" => 9.42},
              "clouds" => {"all" => 99},
              "dt" => 1768438803,
              "sys" => {"sunrise" => 1768457134, "sunset" => 1768500761},
              "timezone" => 0,
              "id" => 6295630,
              "name" => "Globe",
              "cod" => 200
            }.to_json,
            status: 200,
            headers: headers
          }
        )
    end

    it "returns the current temperature" do
      perform_request

      expect(response.parsed_body).to(
        eq(
          {
            "temperature_current" => temp
          }
        )
      )
    end

    context("when the data is already cached") do
      let(:cached_data) { {"cached_data" => true} }
      before do
        Rails.cache.write("forecast/#{zipcode}", cached_data)
      end

      after do
        allow(Rails.cache).to(receive(:read).and_call_original)
      end

      it "returns the cached data" do
        perform_request

        expect(
          a_request(
            :get,
            "#{WeatherApi.base_uri}#{WeatherApi::WEATHER_PATH}"
          )
            .with(
              query: hash_including("units" => "imperial"),
              headers: headers
            )
        )
          .not_to(have_been_made)

        expect(response.parsed_body).to(eq(cached_data.merge("cached" => true)))
      end
    end

    context("when forecast service returns a geocoding error") do
      before do
        stub_request(:get, "#{GeocoderApi.base_uri}#{GeocoderApi::GEOLOCATION_PATH}")
          .with(
            query: {"address" => address, "benchmark" => GeocoderApi::DEFAULT_BENCHMARK, "format" => "json"},
            headers: headers
          )
          .to_return(
            {
              body: {:"errors" => ["Address cannot be empty and cannot exceed 100 characters"], :"status" => "400"}.to_json,
              status: 400,
              headers: weather_response_headers
            }
          )
      end

      it "returns a json error response" do
        perform_request

        expect(response.parsed_body).to(
          eq({"error" => {"code" => nil, "reasons" => ["Address cannot be empty and cannot exceed 100 characters"]}})
        )
      end
    end

    context("when weather API returns an API error") do
      before do
        stub_request(:get, "#{WeatherApi.base_uri}#{WeatherApi::WEATHER_PATH}")
          .with(
            query: {
              "lat" => lat,
              "lon" => lon,
              "units" => "imperial",
              "exclude" => WeatherApi::DEFAULT_EXCLUDE,
              "appid" => api_key
            },
            headers: headers
          )
          .to_return(
            {
              body: {
                "cod" => 401,
                "message" => "Invalid API key. Please see https://openweathermap.org/faq#error401 for more info."
              }.to_json,
              status: 401,
              headers: response_headers
            }
          )
      end

      it "returns a json error response" do
        perform_request

        expect(response.parsed_body).to(
          eq({"error" => {"code" => "weather_api_error", "reasons" => []}})
        )
      end
    end
  end
end
