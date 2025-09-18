Geocoder.configure(
  lookup: (ENV["GEOCODER_LOOKUP"]&.to_sym || :nominatim),
  timeout: 5,
  units: :mi,
  http_headers: {
    "User-Agent" => ENV.fetch("GEOCODER_USER_AGENT", "forecasty-app/1.0 (contact: you@example.com)")
  }
)
