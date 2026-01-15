class ForecastService
  include Singleton

  class << self
    def get_forecast(zipcode)
      # try cache first
      cached_data = Rails.cache.read("forecast/#{zipcode}")
      return cached_data if cached_data.present?

      WeatherApi.new.get_weather(zipcode)
    end
  end
end
