# frozen_string_literal: true

# Handles converting addresses to coordinates and ZIP codes
class GeocodingService
  Result = Data.define(:latitude, :longitude, :zip) do
    def valid?
      latitude && longitude && zip
    end
  end

  class GeocodingError < StandardError; end

  def initialize(geocoder: Geocoder)
    @geocoder = geocoder
  end

  # Convert address to coordinates and ZIP
  def geocode(address)
    return nil if address_blank?(address)

    begin
      geocoder_result = fetch_geocoding_result(address)
      return nil unless geocoder_result

      build_result(geocoder_result)
    rescue => e
      Rails.logger.error("Geocoding failed for address '#{address}': #{e.message}")
      raise GeocodingError, "Unable to geocode address: #{e.message}"
    end
  end

  private

  def address_blank?(address)
    address.to_s.strip.empty?
  end

  def fetch_geocoding_result(address)
    results = @geocoder.search(address)
    results&.first
  end

  # Build result object from geocoder response
  def build_result(geocoder_result)
    zip_code = extract_postal_code(geocoder_result)
    return nil unless zip_code

    Result.new(
      latitude: geocoder_result.latitude,
      longitude: geocoder_result.longitude,
      zip: zip_code
    )
  end

  def extract_postal_code(result)
    result.postal_code || result.data.dig("address", "postcode")
  end
end
