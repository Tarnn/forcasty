# frozen_string_literal: true

# Handles weather forecast requests and responses
class ForecastsController < ApplicationController
  rescue_from GeocodingService::GeocodingError, with: :handle_geocoding_error
  rescue_from WeatherService::WeatherServiceError, with: :handle_weather_error
  rescue_from ForecastCache::CacheError, with: :handle_cache_error

  def new
  end

  def create
    address = extract_address_from_params
    return render_address_error if address.blank?

    geocoding_result = geocode_address(address)
    return render_geocoding_error unless geocoding_result

    weather_result, from_cache = fetch_weather_data(geocoding_result)
    @view_model = build_view_model(address, geocoding_result, weather_result, from_cache)
    render :show
  end

  private

  def extract_address_from_params
    params.require(:forecast).permit(:address)[:address]&.strip
  rescue ActionController::ParameterMissing
    nil
  end

  def geocode_address(address)
    geocoding_service.geocode(address)
  end

  def fetch_weather_data(geocoding_result)
    forecast_cache.fetch_or_store(geocoding_result.zip) do
      weather_service.fetch(
        lat: geocoding_result.latitude,
        lon: geocoding_result.longitude
      )
    end
  end

  def build_view_model(address, geocoding_result, weather_result, from_cache)
    ForecastViewModel.new(
      address: address,
      zip: geocoding_result.zip,
      current_temp_f: weather_result.current_temp_f,
      high_temp_f: weather_result.high_temp_f,
      low_temp_f: weather_result.low_temp_f,
      from_cache: from_cache
    )
  end

  def render_address_error
    flash.now[:alert] = "Please enter an address."
    render :new, status: :unprocessable_content
  end

  def render_geocoding_error
    flash.now[:alert] = "Address not found. Please try a different address."
    render :new, status: :unprocessable_content
  end

  def handle_geocoding_error(exception)
    Rails.logger.error("Geocoding service error: #{exception.message}")
    flash.now[:alert] = "Unable to process the address. Please try again."
    render :new, status: :service_unavailable
  end

  def handle_weather_error(exception)
    Rails.logger.error("Weather service error: #{exception.message}")
    flash.now[:alert] = "Unable to retrieve weather data. Please try again later."
    render :new, status: :bad_gateway
  end

  def handle_cache_error(exception)
    Rails.logger.warn("Cache error (continuing without cache): #{exception.message}")
  end

  def geocoding_service
    @geocoding_service ||= GeocodingService.new
  end

  def weather_service
    @weather_service ||= WeatherService.new
  end

  def forecast_cache
    @forecast_cache ||= ForecastCache.new
  end
end
