# frozen_string_literal: true

# Fetches weather data from external API using coordinates
class WeatherService
  DEFAULT_TIMEOUT = 10

  Result = Data.define(:current_temp_f, :high_temp_f, :low_temp_f, :raw) do
    def valid?
      current_temp_f&.is_a?(Numeric)
    end

    def current_temp_display
      return "N/A" unless current_temp_f
      "#{current_temp_f.round(1)}°F"
    end
  end

  class WeatherServiceError < StandardError; end
  class APIError < WeatherServiceError; end
  class TimeoutError < WeatherServiceError; end
  class InvalidResponseError < WeatherServiceError; end

  def initialize(
    http_client: Faraday,
    base_url: ENV.fetch("WEATHER_BASE_URL", "https://api.open-meteo.com/v1/forecast"),
    timeout: DEFAULT_TIMEOUT
  )
    @http_client = http_client
    @base_url = base_url
    @timeout = timeout
  end

  # Get weather data for coordinates
  def fetch(lat:, lon:)
    validate_coordinates(lat, lon)

    begin
      response = make_weather_request(lat, lon)
      validate_response(response)
      parse_weather_data(response.body)
    rescue Faraday::TimeoutError => e
      raise TimeoutError, "Weather API request timed out: #{e.message}"
    rescue Faraday::Error => e
      raise APIError, "Weather API request failed: #{e.message}"
    rescue JSON::ParserError => e
      raise InvalidResponseError, "Invalid JSON response: #{e.message}"
    end
  end

  private

  def validate_coordinates(lat, lon)
    unless lat.is_a?(Numeric) && lon.is_a?(Numeric)
      raise ArgumentError, "Coordinates must be numeric"
    end

    unless lat.between?(-90, 90) && lon.between?(-180, 180)
      raise ArgumentError, "Coordinates out of valid range"
    end
  end

  def make_weather_request(lat, lon)
    connection.get(@base_url, build_request_params(lat, lon))
  end

  def build_request_params(lat, lon)
    {
      latitude: lat,
      longitude: lon,
      current_weather: true,
      daily: %w[temperature_2m_max temperature_2m_min].join(","),
      temperature_unit: "fahrenheit",
      timezone: "auto"
    }
  end

  def validate_response(response)
    return if response.success?

    error_message = "Weather API error: #{response.status}"
    error_message += " - #{response.body}" if response.body.present?
    raise APIError, error_message
  end

  def connection
    @connection ||= @http_client.new do |faraday|
      faraday.request :url_encoded
      faraday.options.timeout = @timeout
      faraday.options.open_timeout = @timeout / 2
      faraday.response :raise_error
      faraday.adapter :net_http
    end
  end

  # Parse API response into weather result
  def parse_weather_data(response_body)
    payload = JSON.parse(response_body)
    validate_payload_structure(payload)

    Result.new(
      current_temp_f: extract_current_temperature(payload),
      high_temp_f: extract_high_temperature(payload),
      low_temp_f: extract_low_temperature(payload),
      raw: payload
    )
  end

  def validate_payload_structure(payload)
    unless payload.is_a?(Hash)
      raise InvalidResponseError, "Expected JSON object, got #{payload.class}"
    end

    unless payload.key?("current_weather")
      raise InvalidResponseError, "Missing current_weather in response"
    end
  end

  def extract_current_temperature(payload)
    payload.dig("current_weather", "temperature")
  end

  def extract_high_temperature(payload)
    payload.dig("daily", "temperature_2m_max")&.first
  end

  def extract_low_temperature(payload)
    payload.dig("daily", "temperature_2m_min")&.first
  end
end
