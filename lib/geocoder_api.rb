class GeocoderApi < BaseApi
  # Docs: https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html
  # No API key needed
  base_uri "https://geocoding.geo.census.gov"
  format :json

  GEOLOCATION_PATH = "/geocoder/locations/onelineaddress"
  DEFAULT_BENCHMARK = "Public_AR_Current"
  DEFAULT_HEADERS = {"Content-Type" => "application/json"}.freeze
  COORDINATE_PRECISION = 6

  class Error < BaseApi::Error
    DEFAULT_MESSAGE = "Geocoding API request failed"
  end

  # Geocodes the address into {lat, long, zipcode}
  def geocode(address)
    response = self.class.get(
      GEOLOCATION_PATH,
      query: {
        address: address,
        benchmark: DEFAULT_BENCHMARK,
        format: "json"
      },
      headers: DEFAULT_HEADERS
    )

    if response.code == 200
      data = response.parsed_response
      address_matches = data.dig("result").dig("addressMatches")

      # If for some reason, the JSON isn't as we expect, we raise a parse error.
      # The docs don't specify that this can happen, but it is a different error
      # than when matches is an empty array, since the docs specifically mention
      # that happens when no matches can be found.
      if address_matches.nil?
        raise Error.new("Failed to parse geocoding response", code: :parse_geocode_response_failure)
      end

      # Census API will return an empty array of matches when it can't find any
      if address_matches.length.zero?
        raise Error.new("No matches found for address", code: :address_not_found)
      end

      address = address_matches.first
      coords = address["coordinates"]

      # Rounded to precision 6 because OpenWeatherMap API says that is common
      # practice, and results in accuracy up to approximately 0.11 meters
      # See https://openweathermap.org/support-centre
      return {
        lat: self.class.round(coords["y"]),
        long: self.class.round(coords["x"]),
        zipcode: address["addressComponents"]["zip"]
      }
    else
      Rails.logger.tagged("GeocoderApi") do
        if response.parsed_response
          # E.g. ["Address cannot be empty and cannot exceed 100 characters"]
          reasons = response.parsed_response.dig("errors")
          if reasons
            # Here we pass Census API error messages as reasons, meant for debugging
            Rails.logger.error("Failed to geocode address '#{address}', reasons: #{reasons.inspect}")
            raise Error.new("Failed to geocode address", reasons: reasons, code: :geocode_address_errors)
          else
            # If the Census API didn't provide any reasons for the error, we mark
            # it as unknown
            Rails.logger.error("Failed to geocode address '#{address}', no reasons given")
            raise Error.new("Failed to geocode address")
          end
        else
          # HTTParty a nil `parsed_response` if the encoding is invalid, or
          # if there's other non-parser issues; See `httparty-0.24.0/lib/httparty/parser.rb:107`

          # Raise a parse failure if the response was not able to be parsed
          Rails.logger.error("Failed to parse geocoding response")
          raise Error.new("Failed to parse geocoding response")
        end
      end
    end

  rescue JSON::ParserError => e
    # Raise a parse failure error if the response failed to parse. This may happen
    # when calling response.parsed_response for the first time; See `httparty-0.24.0/lib/httparty/response.rb:37`
    raise Error.new("Failed to parse geocoding response: #{e.message}")
  end

  # Centralize rounding logic
  def self.round(num, precision = COORDINATE_PRECISION)
    num.round(precision)
  end
end
