class WeatherApi
  include HTTParty

  base_uri "https://api.openweathermap.org"
  format :json

  WEATHER_PATH = "/data/2.5/weather"
  FORECAST_PATH = "/data/2.5/forecast"
  WEATHER_CACHE_EXPIRY = 60 * 30

  DEFAULT_UNIT = "imperial"
  DEFAULT_EXCLUDE = "minutely,hourly,alerts"
  DEFAULT_HEADERS = {"Content-Type" => "application/json"}.freeze

  class Error < StandardError
    attr_reader :code, :reasons, :request_id

    def initialize(message = "Weather API request failed", metadata = {})
      super(message)

      @code = metadata[:code]
      @reasons = metadata[:reasons]
    end
  end

  def initialize
    @api_key = Rails.application.credentials.open_weather_map_api_key
    raise Error.new("API Key missing") unless @api_key
  end

  # address_data should have lat, long, and zipcode
  def get_weather(address_data)
    lat = address_data[:lat]
    long = address_data[:long]
    zipcode = address_data[:zipcode]

    response = self
      .class
      .get(
        WEATHER_PATH,
        query: {lat: lat, lon: long, units: DEFAULT_UNIT, exclude: DEFAULT_EXCLUDE, appid: @api_key},
        headers: DEFAULT_HEADERS
      )
    if response.code == 200
      parsed_response = response.parsed_response
      current_weather = parsed_response["main"]

      current_temp = current_weather["temp"]

      # Could not find a free way to get current day low/high temps, these are local min/maxes
      # low_temp = current_weather["temp_min"]
      # high_temp = current_weather["temp_max"]

      weather_data = {
        temperature_current: current_temp
      }

      # The census API says it sometimes will not return zipcode
      if zipcode
        Rails.cache.write("forecast/#{zipcode}", weather_data, {expires_in: WEATHER_CACHE_EXPIRY})
      end

      weather_data
    else
      handle_api_error(response, "Error fetching weather data", code: :weather_api_error)
    end
  end

  private

  def handle_api_error(response, message, metadata = {})
    begin
      parsed_response = response.parsed_response
      raise Error.new("#{message}: #{parsed_response["message"]}", **metadata)
    rescue JSON::ParserError => e
      raise Error.new("Unable to parse error response: #{e.message}", **metadata)
    end
  end
end
