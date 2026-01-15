require "spec_helper"

RSpec.describe ForecastsController, type: :request do
  subject(:perform_request) { get("/forecasts") }
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
  let(:zipcode) { "33760" }
  let(:lat) { 27.9004 }
  let(:lon) { -82.7152 }
  let(:temp) { 60.53 }
  let(:temp_min) { 58.14 }
  let(:temp_max) { 63.05 }
  let(:api_key) { "abc123" }

  it "renders a json error if zipcode is missing" do
    perform_request

    expect(response.parsed_body).to(
      eq(
        {
          "error" => "zip_code parameter is required"
        }
      )
    )
  end

  before do
    allow(Rails).to(receive(:cache).and_return(memory_store))
    Rails.cache.clear
  end

  context("when zipcode is present") do
    subject(:perform_request) { get("/forecasts?zipcode=33760") }

    before do
      allow(Rails.application.credentials).to(receive(:open_weather_map_api_key).and_return(api_key))

      stub_request(:get, "#{WeatherApi.base_uri}#{WeatherApi::GEOLOCATION_PATH}")
        .with(
          query: {"zip" => zipcode, "appid" => api_key},
          headers: headers
        )
        .to_return(
          {
            body: {
              "zip" => "33760",
              "name" => "Largo",
              "lat" => lat,
              "lon" => lon,
              "country" => "US"
            }.to_json
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
      expect(a_request(:get, "#{WeatherApi.base_uri}#{WeatherApi::WEATHER_PATH}")).not_to(have_been_made)
      perform_request

      expect(response.parsed_body).to(
        eq(
          {
            "temperature_current" => temp,
            "temperature_low" => temp_min,
            "temperature_high" => temp_max
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
            "https://api.openweathermap.org/data/2.5/weather"
          )
            .with(
              query: hash_including("units" => "imperial"),
              headers: headers
            )
        )
          .not_to(have_been_made)

        expect(response.parsed_body).to(eq(cached_data))
      end
    end
  end
end
