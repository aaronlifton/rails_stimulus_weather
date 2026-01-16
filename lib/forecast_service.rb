class ForecastService
  class << self
    def get_forecast(address)
      # Errors from #geocode are handled by the controller
      address_data = GeocoderApi.new.geocode(address)

      zipcode = address_data[:zipcode]

      # try cache first
      cached_data = Rails.cache.read("forecast/#{zipcode}")
      return cached_data.merge({cached: true}) if cached_data.present?

      # Errors from #get_weather are handled by the controller
      WeatherApi.new.get_weather(address_data)
    end
  end
end
