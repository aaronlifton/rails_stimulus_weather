class ForecastService
  include Singleton

  class << self
    def get_forecast(address)
      address_data = nil
      begin
        address_data = GeocoderApi.new.geocode(address)
      rescue GeocoderApi::Error
        raise
      end

      zipcode = address_data[:zipcode]

      # try cache first
      cached_data = Rails.cache.read("forecast/#{zipcode}")
      return cached_data.merge({cached: true}) if cached_data.present?

      WeatherApi.new.get_weather(address_data)
    end
  end
end
