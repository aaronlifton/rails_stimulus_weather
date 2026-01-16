# Geocodes the address, gets the weather, and propagates errors from
# service classes
class ForecastService
  class << self
    def get_forecast(address)
      # Errors from #geocode should be handled by the caller (rescue BaseApi::Error)
      address_data = GeocoderApi.new.geocode(address)

      zipcode = address_data[:zipcode]

      # Try cache before calling the weather API. Caching by zipcode helps reduce API calls for nearby
      # addresses.
      cached_data = Rails.cache.read("forecast/#{zipcode}")
      # The "cached" tag is used by the frontend
      return cached_data.merge({cached: true}) if cached_data.present?

      # Errors from #get_weather should be handled by the caller (rescue BaseApi::Error)
      WeatherApi.new.get_weather(address_data)
    end
  end
end
