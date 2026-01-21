require "spec_helper"

require("weather_api")

RSpec.describe WeatherApi do
  subject(:weather_api) { described_class.new }

  let(:lat) { -76.927487242301 }
  let(:lon) { 38.846016223866 }
  let(:zipcode) { "20233" }
  let(:address_data) { {lat: lat, long: lon, zipcode: zipcode} }
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
      "date" => ["Thu, 15 Jan 2026 23:38:48 GMT"],
      "content-type" => ["application/json; charset=utf-8"],
      "content-length" => ["108"],
      "connection" => ["close"],
      "x-cache-key" => ["/data/2.5/weather?sdf=1"],
      "access-control-allow-origin" => ["*"],
      "access-control-allow-credentials" => ["true"],
      "access-control-allow-methods" => ["GET, POST"]
    }
  }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  describe "initialization" do
    before do
      allow(Rails.application.credentials).to(receive(:open_weather_map_api_key).and_return(nil))
    end

    it "raises an error when api key is missing" do
      expect { described_class.new }.to(raise_error("API Key missing"))
    end
  end

  before do
    allow(Rails).to(receive(:cache).and_return(memory_store))
    Rails.cache.clear

    allow(Rails.application.credentials).to(receive(:open_weather_map_api_key).and_return(api_key))

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
          headers: response_headers
        }
      )
  end

  it "gets weather data" do
    data = weather_api.get_weather(address_data)
    expect(data).to(
      eq(
        {
          temperature_current: temp
        }
      )
    )
  end

  it "writes to the cache" do
    cache_data = {
      temperature_current: temp
    }
    expect(Rails.cache.read("forecast/#{zipcode}")).to(be_nil)
    expect(Rails.cache)
      .to(
        receive(:write).with("forecast/#{zipcode}", cache_data, {expires_in: described_class::WEATHER_CACHE_EXPIRY})
      )
      .and_call_original

    weather_data = weather_api.get_weather(address_data)
    expect(weather_data).to(eq(cache_data))

    expect(Rails.cache.read("forecast/#{zipcode}")).to(eq(cache_data))
  end

  context("when the weather api returns a 401") do
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
              "cod" => 401,
              "message" => "Invalid API key. Please see https://openweathermap.org/faq#error401 for more info."
            }.to_json,
            status: 401,
            headers: response_headers
          }
        )
    end

    it "handles the api error" do
      expect(Rails.logger).to(receive(:error).with(include("Invalid API key")))

      expect { weather_api.get_weather(address_data) }.to(
        raise_error(described_class::Error, include("Error fetching weather data"))
      )
    end
  end

  context("when the weather api returns unparsable json") do
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
              "cod" => 404
            }.to_json +
              "asdf",
            status: 404,
            headers: response_headers
          }
        )
    end

    it "handles the api error" do
      expect { weather_api.get_weather(address_data) }.to(
        raise_error(described_class::Error, include("Unable to parse"))
      )
    end
  end
end
