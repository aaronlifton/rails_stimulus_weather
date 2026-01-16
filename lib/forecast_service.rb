# Geocodes the address, gets the weather, and propagates errors from
# service classes
class ForecastService
  class << self
    def get_forecast(address)
      cache_key = address_cache_key(address)
      address_data = Rails.cache.read(cache_key)
      zipcode = address_data.try(:[], :zipcode)

      # Cache geocoded address data, to reduce API calls and response time
      unless address_data
        # Errors from #geocode should be handled by the caller (rescue BaseApi::Error)
        address_data = GeocoderApi.new.geocode(address)

        zipcode = address_data[:zipcode]
        Rails.cache.write(cache_key, address_data)
      end

      if zipcode
        # Try cache before calling the weather API. Caching by zipcode helps reduce API calls for nearby
        # addresses.
        cached_forecast_data = Rails.cache.read("forecast/#{zipcode}")
        # The "cached" tag is used by the frontend
        return cached_forecast_data.merge({cached: true}) if cached_forecast_data.present?
      end

      # Errors from #get_weather should be handled by the caller (rescue BaseApi::Error)
      WeatherApi.new.get_weather(address_data)
    end

    def address_cache_key(address)
      hash = Digest::SHA256.hexdigest(address.downcase)
      "address/#{hash}"
    end
  end
end
