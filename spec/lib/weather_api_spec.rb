require "spec_helper"

require("weather_api")

RSpec.describe WeatherApi do
  subject(:weather_api) { described_class.new }
  let(:zipcode) { "33760" }
  let(:lat) { 27.9004 }
  let(:lon) { -82.7152 }
  let(:temp) { 60.53 }
  let(:temp_min) { 58.14 }
  let(:temp_max) { 63.05 }
  let(:api_key) { "abc123" }
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
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  # let(:weather_response_headers) {
  #   {
  #     "date" => ["Thu, 15 Jan 2026 00:35:49 GMT"],
  #     "content-type" => ["application/json; charset=utf-8"],
  #     "content-length" => ["484"],
  #     "connection" => ["close"],
  #     "x-cache-key" => ["/data/2.5/weather?lat=0&lon=0"],
  #     "access-control-allow-origin" => ["*"],
  #     "access-control-allow-credentials" => ["true"],
  #     "access-control-allow-methods" => ["GET, POST"]
  #   }
  # }

  before do
    allow(Rails).to(receive(:cache).and_return(memory_store))
    Rails.cache.clear

    expect(Rails.application.credentials).to(receive(:open_weather_map_api_key).and_return(api_key))

    stub_request(:get, "#{described_class.base_uri}#{described_class::GEOLOCATION_PATH}")
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

    stub_request(:get, "#{described_class.base_uri}#{described_class::WEATHER_PATH}")
      .with(
        query: {
          "lat" => lat,
          "lon" => lon,
          "units" => "imperial",
          "exclude" => described_class::DEFAULT_EXCLUDE,
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

    stub_request(:get, "#{described_class.base_uri}#{described_class::GEOLOCATION_ADDRESS_PATH}")
      .with(
        query: {
          "q" => "Clearwater,FL,US",
          "appid" => api_key
        },
        headers: headers
      )
      .to_return(
        body: [
          {
            :"name" => "Clearwater",
            :"local_names" => {:"en" => "Clearwater"},
            :"lat" => 27.9658533,
            :"lon" => -82.8001026,
            :"country" => "US",
            :"state" => "Florida"
          }
        ].to_json,
        status: 200,
        headers: headers
      )
  end

  it "gets weather data" do
    data = weather_api.get_weather(zipcode)
    expect(data).to(
      eq(
        {
          temperature_current: temp,
          temperature_low: temp_min,
          temperature_high: temp_max
        }
      )
    )
  end

  it "writes to the cache" do
    data = {
      temperature_current: temp,
      temperature_low: temp_min,
      temperature_high: temp_max
    }
    expect(Rails.cache.read("forecast/#{zipcode}")).to(be_nil)

    weather_data = weather_api.get_weather(zipcode)
    expect(weather_data).to(eq(data))

    expect(Rails.cache.read("forecast/#{zipcode}")).to(eq(data))
  end

  context("when the geolocation API returns a 500 error") do
    let(:response_status) { 500 }
    let(:error_message) { "Internal Server Error" }

    before do
      stub_request(:get, "#{described_class.base_uri}#{described_class::GEOLOCATION_PATH}")
        .with(
          query: {"zip" => zipcode, "appid" => api_key},
          headers: headers
        )
        .to_return(
          {
            body: {
              cod: response_status,
              message: error_message
            }.to_json,
            status: response_status,
            headers: response_headers
          }
        )
    end

    it "raises an error with the api error" do
      expect { weather_api.get_weather(zipcode) }.to(
        raise_error(described_class::Error, "Error fetching geolocation data: Internal Server Error")
      )
    end

    context("when the weather API returns a 401 error") do
      let(:error_message) { "Invalid API key" }

      it "raises an error with the api error" do
        expect { weather_api.get_weather(zipcode) }.to(
          raise_error(described_class::Error, "Error fetching geolocation data: Invalid API key")
        )
      end
    end
  end

  context("when the geolocation API returns a 500 error") do
    let(:response_status) { 500 }
    let(:error_message) { "Internal Server Error" }

    before do
      stub_request(:get, "#{described_class.base_uri}#{described_class::WEATHER_PATH}")
        .with(
          query: {
            "lat" => lat,
            "lon" => lon,
            "units" => "imperial",
            "exclude" => described_class::DEFAULT_EXCLUDE,
            "appid" => api_key
          },
          headers: headers
        )
        .to_return(
          {
            body: {
              cod: response_status,
              message: error_message
            }.to_json,
            status: response_status,
            headers: response_headers
          }
        )
    end

    it "raises an error with the api error" do
      expect { weather_api.get_weather(zipcode) }.to(
        raise_error(described_class::Error, "Error fetching weather data: Internal Server Error")
      )
    end

    context("when the weather API returns a 401 error") do
      let(:error_message) { "Invalid API key" }

      it "raises an error with the api error" do
        expect { weather_api.get_weather(zipcode) }.to(
          raise_error(described_class::Error, "Error fetching weather data: Invalid API key")
        )
      end
    end
  end

  context("when the geolocation API returns an unparsable body") do
    let(:response_status) { 500 }
    let(:error_message) { "Internal Server Error" }

    before do
      stub_request(:get, "#{described_class.base_uri}#{described_class::WEATHER_PATH}")
        .with(
          query: {
            "lat" => lat,
            "lon" => lon,
            "units" => "imperial",
            "exclude" => described_class::DEFAULT_EXCLUDE,
            "appid" => api_key
          },
          headers: headers
        )
        .to_return(
          {
            body: {
              cod: response_status,
              message: error_message
            }.to_json +
              "asdf",
            status: response_status,
            headers: response_headers
          }
        )
    end

    it "raises a parse error" do
      expect { weather_api.get_weather(zipcode) }.to(
        raise_error(described_class::Error, including("Unable to parse error response: unexpected token"))
      )
    end
  end
end
