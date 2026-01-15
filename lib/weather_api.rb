class WeatherApi
  include HTTParty

  base_uri "https://api.openweathermap.org"
  format :json

  WEATHER_PATH = "/data/2.5/weather"
  GEOLOCATION_PATH = "/geo/1.0/zip"
  DAILY_PATH = "forecast/daily?lat={lat}&lon={lon}&cnt={cnt}&appid={API key}"

  DEFAULT_UNIT = "imperial"
  DEFAULT_EXCLUDE = "minutely,hourly,alerts"
  DEFAULT_PARAMS = {appid: @api_key}.freeze
  DEFAULT_HEADERS = {"Content-Type" => "application/json"}.freeze
  DEFALT_CNT = 1

  class Error < StandardError
  end

  def initialize
    @api_key = Rails.application.credentials.open_weather_map_api_key
  end

  def get_weather(zipcode)
    lat, long = generate_lat_long(zipcode)
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
      low_temp = current_weather["temp_min"]
      high_temp = current_weather["temp_max"]

      # {temperature: 292.17, low_temperature: 290.99, high_temperature: 293.25}
      weather_data = {
        temperature_current: current_temp,
        temperature_low: low_temp,
        temperature_high: high_temp
      }

      Rails.cache.write("forecast/#{zipcode}", weather_data)
      weather_data
    else
      handle_api_error(response, "Error fetching weather data")
    end
  end

  def generate_lat_long(zipcode)
    response = self
      .class
      .get(
        GEOLOCATION_PATH,
        query: {zip: zipcode, appid: @api_key},
        headers: DEFAULT_HEADERS
      )
    if response.code == 200
      data = response.parsed_response
      [data["lat"], data["lon"]]
    else
      handle_api_error(response, "Error fetching geolocation data")
    end
  end

  private

  def handle_api_error(response, message)
    begin
      parsed_response = response.parsed_response
      raise Error.new("#{message}: #{parsed_response["message"]}")
    rescue JSON::ParserError => e
      raise Error.new("Unable to parse error response: #{e.message}")
    end
  end
end
