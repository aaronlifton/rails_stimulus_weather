require "spec_helper"

require "forecast_service"

RSpec.describe ForecastService do
  subject(:forecast_service) { described_class }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:address) { "4600 Silver Hill Rd, Washington, DC" }
  let(:geocoder_mock) { instance_double(GeocoderApi) }
  let(:weather_mock) { instance_double(WeatherApi) }
  let(:lat) { -76.927487242301 }
  let(:lon) { 38.846016223866 }
  let(:zipcode) { "20233" }
  let(:address_data) { {lat: lat, long: lon, zipcode: zipcode} }

  before do
    allow(Rails).to(receive(:cache).and_return(memory_store))
    Rails.cache.clear

    allow(GeocoderApi).to(receive(:new).and_return(geocoder_mock))
    allow(WeatherApi).to(receive(:new).and_return(weather_mock))
  end

  context("when the geolocation API raises an error") do
    before do
      allow(geocoder_mock)
        .to(
          receive(:geocode).with(address)
        )
        .and_raise(GeocoderApi::Error.new("Error fetching geolocation"))
    end

    it "raises an error with the api error" do
      expect { forecast_service.get_forecast(address) }.to(
        raise_error(GeocoderApi::Error, "Error fetching geolocation")
      )
    end
  end

  context("when the weather API raises an error") do
    let(:response_status) { 500 }
    let(:error_message) { "Internal Server Error" }

    before do

      allow(geocoder_mock).to(
        receive(:geocode).with(address).and_return(address_data)
      )
      allow(weather_mock).to(
        receive(:get_weather).with(address_data).and_raise(WeatherApi::Error.new("Error fetching weather data"))
      )
    end

    it "raises an error with the api error" do
      expect { forecast_service.get_forecast(address) }.to(
        raise_error(WeatherApi::Error, "Error fetching weather data")
      )
    end
  end

  context("when the happy path is followed") do
    let(:current_temp) { 79 }
    let(:weather_data) { {temperature_current: current_temp} }

    before do
      allow(geocoder_mock).to(
        receive(:geocode).with(address).and_return(address_data)
      )
      allow(weather_mock).to(
        receive(:get_weather).with(address_data).and_return(
          weather_data
        )
      )
    end

    it "returns the retrieved weather data" do
      expect(forecast_service.get_forecast(address)).to(eq(weather_data))
    end

    context("when the data is already cached") do
      let(:cached_data) { {"cached_data" => true} }
      before do
        Rails.cache.write("forecast/#{zipcode}", cached_data)
      end

      after do
        allow(Rails.cache).to(receive(:read).and_call_original)
      end

      it "returns the cached data and adds a cached tag" do
        expect(weather_mock).not_to(receive(:get_weather))

        expect(forecast_service.get_forecast(address)).to(
          eq(
            cached_data.merge(cached: true)
          )
        )
      end
    end
  end
end
