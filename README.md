# Forecasty Weather App

A straightforward Rails application that lets you enter any address and get the current weather forecast. The app intelligently caches results by ZIP code for 30 minutes to avoid unnecessary API calls, and clearly shows you whether you're seeing fresh data or cached results.

## Tech Stack

- Rails 8 + Ruby 3.3
- SQLite database
- Geocoder gem (Nominatim provider)
- Faraday for HTTP requests
- Open-Meteo weather API
- Rails caching
- RSpec + WebMock for testing

## Architecture

- **Service Objects**: Geocoding, Weather, and Cache services
- **View Models**: Presentation logic
- **Error Handling**: Graceful degradation
- **Caching**: 30-minute ZIP-based cache

## Getting Started

You'll need Ruby 3.3+ and Bundler installed.

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Configure environment (optional):**
   Copy `.env.example` to `.env` and adjust settings if needed. The defaults work out of the box.

3. **Start the server:**
   ```bash
   bin/rails server
   ```

4. **Try it out:**
   Open http://localhost:3000 and enter any address (like "1600 Amphitheatre Parkway, Mountain View, CA").

## Running Tests

The test suite covers all major functionality with both unit and integration tests:

```bash
bundle exec rspec
```

Tests include edge cases, error scenarios, and verify caching behavior.

## How It Works

1. User enters an address
2. GeocodingService converts address to coordinates + ZIP
3. ForecastCache checks for cached weather data
4. If no cache, WeatherService fetches from Open-Meteo API
5. Results displayed with cache status indicator

## Code Structure

```
app/
├── controllers/forecasts_controller.rb    # Main controller
├── services/                             # Business logic
│   ├── geocoding_service.rb
│   ├── weather_service.rb
│   └── forecast_cache.rb
├── view_models/forecast_view_model.rb    # Presentation logic
└── views/forecasts/                      # Templates
```

## Production Ready

- Comprehensive error handling
- Structured logging
- Health check endpoints
- CSRF protection
- Service-based architecture for scaling

## API Dependencies

**Geocoding**: Uses Nominatim (OpenStreetMap) by default, which is free but requires a proper User-Agent header. You can switch to Google, Bing, or other providers by updating the configuration.

**Weather**: Uses Open-Meteo, a free weather API that doesn't require registration. It provides reliable data in multiple formats and units.

Both services are production-ready and handle reasonable traffic volumes without issues.
