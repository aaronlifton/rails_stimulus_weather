# Weather app

---

```sh
❯ curl "https://api.openweathermap.org/data/2.5/weather?lat=0&lon=0&appid=fde37e00edc68468e2a4aea09ef24777"
```

```json
{
  "coord": { "lon": 0, "lat": 0 },
  "weather": [
    {
      "id": 804,
      "main": "Clouds",
      "description": "overcast clouds",
      "icon": "04d"
    }
  ],
  "base": "stations",
  "main": {
    "temp": 300.24,
    "feels_like": 302.43,
    "temp_min": 300.24,
    "temp_max": 300.24,
    "pressure": 1010,
    "humidity": 73,
    "sea_level": 1010,
    "grnd_level": 1010
  },
  "visibility": 10000,
  "wind": { "speed": 2.91, "deg": 263, "gust": 3.21 },
  "clouds": { "all": 100 },
  "dt": 1768396543,
  "sys": { "sunrise": 1768370712, "sunset": 1768414340 },
  "timezone": 0,
  "id": 6295630,
  "name": "Globe",
  "cod": 200
}
```

```sh
curl "http://api.openweathermap.org/geo/1.0/zip?zip=33760&appid=fde37e00edc68468e2a4aea09ef24777"
```

```json
{
  "zip": "33760",
  "name": "Largo",
  "lat": 27.9004,
  "lon": -82.7152,
  "country": "US"
}
```
