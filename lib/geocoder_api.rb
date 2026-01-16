class GeocoderApi
  include HTTParty

  base_uri "https://geocoding.geo.census.gov"
  format :json

  GEOLOCATION_PATH = "/geocoder/locations/onelineaddress"
  DEFAULT_BENCHMARK = "Public_AR_Current"
  DEFAULT_HEADERS = {"Content-Type" => "application/json"}.freeze

  class Error < StandardError
    attr_reader :code, :reasons, :request_id

    def initialize(message = "Geocoding API request failed", metadata = {})
      super(message)

      @code = metadata[:code]
      @reasons = metadata[:reasons]
    end
  end

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
      result = data["result"]
      address_matches = result["addressMatches"]

      if address_matches.length.zero?
        raise Error.new("No matches found for address", code: :address_not_found)
      end

      address = address_matches.first
      coords = address["coordinates"]

      return {
        lat: coords["y"].round(7),
        long: coords["x"].round(7),
        zipcode: address["addressComponents"]["zip"]
      }
    else
      if response.parsed_response
        # ["Address cannot be empty and cannot exceed 100 characters"]
        reasons = response.parsed_response.dig("errors")
        if reasons
          raise Error.new("Failed to geocode address", reasons: reasons)
        else
          raise Error.new("Failed to geocode address", code: :unknown_error)
        end
      else
        raise Error.new("Failed to parse geocoding response", code: :parse_geocode_response_failure)
      end
    end
  end
end
