# Forecasty

Weather forecast app built with Rails. Enter an address, get current weather conditions.

## Demo

🌐 **Live Demo**: https://forcasty-production.up.railway.app/

[![Demo Video](https://img.youtube.com/vi/ZTKRNAD0I5A/maxresdefault.jpg)](https://youtu.be/ZTKRNAD0I5A)

[🎥 Watch the demo](https://youtu.be/ZTKRNAD0I5A)

## Setup

```bash
bundle install
rails tailwindcss:build
bin/rails server
```

Visit http://localhost:3000

## Tests

```bash
bundle exec rspec
```

## Architecture

- **Services**: Geocoding (Nominatim), Weather (Open-Meteo), Caching
- **View Models**: Presentation logic separation
- **Caching**: 30-minute ZIP-based cache to reduce API calls

## Tech Stack

- Rails 8, Ruby 3.3
- SQLite
- Geocoder gem
- Open-Meteo API (free, no auth required)
- RSpec + WebMock

## Key Features

- Address → coordinates → weather data pipeline
- Intelligent caching by ZIP code
- Cache hit/miss indicators
- Error handling for API failures
- Service object pattern
