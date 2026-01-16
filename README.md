# Weather App

- Rails + Stimulus app that fetches the current temperature for a user-provided address
- Uses the US Census Geocoder to turn an address into lat/long, then calls OpenWeatherMap for current conditions.
- Results are cached by ZIP code.

## Requirements

- Ruby/Rails app with credentials set for `open_weather_map_api_key`
  - Get API key from OpenWeatherMap
  - `rails credentials:edit`
- Node/npm (or yarn) for JS assets

## Dev requirements

- mise
- rubyfmt (`brew install rubyfmt`)
- biome (installs via `mise.toml` via `mise install`)
- ruby-lsp

---

## Dev setup

```sh
bin/setup
mise install
bin/dev
```

Open `http://localhost:3000` and enter an address (Preferably line1, line2, city, and state).

### Testing

Backend

`mise exec -- bundle exec rspec`

Frontend

`npm test`

---

## Object decomposition

### 1) Input: address (string)

- The user-provided address becomes `ForecastsController#index` query param `address`
- The `ForecastsController` and the frontend validate its presence

### 2) `ForecastService` orchestrates the APIs

2. `ForecastsController` calls `ForecastService`
1. `ForecastService` Geocodes the user-given address via `GeocoderApi` into an
   `address_data` hash (see #2)
1. `ForecastService` then calls `WeatherApi` to get the current weather report based on the geocoded address, and returns it (see #3)

### 2) Geocoding result: `address_data` (hash)

`GeocoderApi#geocode` returns the following `address_data`:

```json
{
  "lat": 38.8976997,
  "long": -77.0365532,
  "zipcode": "20500"
}
```

- `lat`: latitude (float, 7-decimal)
- `long`: longitude (float, 7-decimal)
- `zipcode`: string; census API may omit it based on address (see census API
  docs)

### 3) Weather response: `weather_data` (hash)

`WeatherApi#get_weather` returns the following `weather_data` and returns it to the controller:

```json
{
  "temperature_current": 72
}
```

- `temperature_current`: current temperature in Fahrenheit (OpenWeatherMap calls this `imperial` units)

### 4) `ForecastService` returns a `forecast` (hash)

`ForecastService.get_forecast` adds a cached tag to the `weather_data` hash if the data was fetched from cache.

```json5
{
  temperature_current: 72,
  cached: true, // Added by ForecastService
}
```

- `cached`: present if the result was retrieved from cache (expires every 30
  minutes [https://github.com/aaronlifton/rails_stimulus_weather/blob/main/lib/weather_api.rb#L60])

### 5) Backend error format

Returns a `code` so the frontend can handle user-friendly error messages, and
`reasons`, containing multiple backend error messages, if present.

```json
{
  "error": {
    "message": "API Error",
    "code": "address_required",
    "reasons": []
  }
}
```

- `message`: non user-friendly backend error message
- `code`: symbolic error code for UI presentation of backend errors
- `reasons`: optional list (for API error messages)

- Errors are modeled as custom exception types (`GeocoderApi::Error`, `WeatherApi::Error`), which helps keep controller logic straightforward (controllers just handle error types).

## Code map

- `app/controllers/forecasts_controller.rb`: request validation + JSON response
- `lib/forecast_service.rb`: orchestrates the geocoding, caching, and weather
  retrieval
- `lib/geocoder_api.rb`: Census geocoding API
- `lib/weather_api.rb`: OpenWeatherMap API, writes to cache
- `app/javascript/controllers/forecast_controller.js`: Stimulus controller and backend <-> frontend error mapping
