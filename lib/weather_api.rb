class WeatherApi < BaseApi
  # Docs: https://openweathermap.org/current
  base_uri "https://api.openweathermap.org"
  format :json

  WEATHER_PATH = "/data/2.5/weather"
  FORECAST_PATH = "/data/2.5/forecast"
  WEATHER_CACHE_EXPIRY = 60 * 30

  DEFAULT_UNIT = "imperial"
  DEFAULT_EXCLUDE = "minutely,hourly,alerts"
  DEFAULT_HEADERS = {"Content-Type" => "application/json"}.freeze

  class Error < BaseApi::Error
    DEFAULT_MESSAGE = "Weather API request failed"
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

      # Could not find a free way to get current day low/high temps, these are coordinate-local min/maxes
      # low_temp = current_weather["temp_min"]
      # high_temp = current_weather["temp_max"]

      weather_data = {
        temperature_current: current_temp
      }

      # The Census API docs don't specifically say values for all fields will always be
      # returned, so protect against case where they're not
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
    # When the OpenWeatherMap API returns an error, they return it as json containing a message:
    # { "cod": 401, "message": "Invalid API key. Please see https://openweathermap.org/faq#error401 for more info." }
    begin
      parsed_response = response.parsed_response
      raise Error.new("#{message}: #{parsed_response["message"]}", **metadata)
    rescue JSON::ParserError => e
      raise Error.new("Unable to parse error response: #{e.message}", **metadata)
    end
  end
end
