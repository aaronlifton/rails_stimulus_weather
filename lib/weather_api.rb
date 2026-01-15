class WeatherApi
  include HTTParty

  base_uri "https://api.openweathermap.org"
  format :json

  WEATHER_PATH = "/data/2.5/weather"
  GEOLOCATION_ZIPCODE_PATH = "/geo/1.0/zip"
  GEOLOCATION_ADDRESS_PATH = "/geo/1.0/direct"
  FORECAST_PATH = "/data/2.5/forecast"
  # ZIP_WEATHER_PATH = "https://api.openweathermap.org/data/2.5/forecast?zip=33760&cnt=1&appid=fde37e00edc68468e2a4aea09ef24777"

  DEFAULT_UNIT = "imperial"
  DEFAULT_EXCLUDE = "minutely,hourly,alerts"
  DEFAULT_HEADERS = {"Content-Type" => "application/json"}.freeze

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

      weather_data = {
        temperature_current: current_temp,
        temperature_low: low_temp,
        temperature_high: high_temp
      }

      Rails.cache.write("forecast/#{zipcode}", weather_data, {expires_in: 60 * 30})
      weather_data
    else
      handle_api_error(response, "Error fetching weather data")
    end
  end

  def generate_lat_long(zipcode)
    response = self
      .class
      .get(
        GEOLOCATION_ZIPCODE_PATH,
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

  def generate_lat_long(address)
    # ?q={city name},{state code},{country code}&limit={limit}&appid={API key}
    response = self
      .class
      .get(
        GEOLOCATION_ADDRESS_PATH,
        query: {q: address, limit: 1, appid: @api_key},
        headers: DEFAULT_HEADERS
      )
    debugger
    if response.code == 200
      data = response.parsed_response
      [data["lat"], data["lon"]]
    else
      handle_api_error(response, "Error fetching geolocation data")
    end
  end

  # def get_daily_weather(zipcode)
  #   response = self
  #     .class
  #     .get(
  #       FORECAST_PATH,
  #       query: {zip: zipcode, units: DEFAULT_UNIT, cnt: DEFAULT_CNT, appid: @api_key},
  #       headers: DEFAULT_HEADERS
  #     )
  #   if response.code == 200
  #     data = response.parsed_response
  #     today = data["list"].first
  #     weather_data = today["main"]
  #
  #     {
  #       temp: weather_data["temp"]
  #     }
  #   else
  #     handle_api_error(response, "Error fetching geolocation data")
  #   end
  # end

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
