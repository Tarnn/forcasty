# frozen_string_literal: true

# Prepares weather data for display in views
class ForecastViewModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :address, :string
  attribute :zip, :string
  attribute :current_temp_f, :float
  attribute :high_temp_f, :float
  attribute :low_temp_f, :float
  attribute :from_cache, :boolean, default: false

  validates :address, presence: true
  validates :zip, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a valid ZIP code" }
  validates :current_temp_f, presence: true, numericality: true

  def formatted_current_temp
    return "N/A" unless current_temp_f
    "#{current_temp_f.round(1)}°F"
  end

  def formatted_high_temp
    return "N/A" unless high_temp_f
    "#{high_temp_f.round(1)}°F"
  end

  def formatted_low_temp
    return "N/A" unless low_temp_f
    "#{low_temp_f.round(1)}°F"
  end

  # Get user-friendly cache status text
  def cache_status_message
    from_cache? ? "Result served from cache" : "Fresh result"
  end

  def high_low_available?
    high_temp_f.present? && low_temp_f.present?
  end

  def temperature_range
    return "N/A" unless high_low_available?
    "#{formatted_high_temp} / #{formatted_low_temp}"
  end

  # Format address with ZIP for display
  def full_address_display
    "#{address} (#{zip})"
  end

  def from_cache?
    from_cache == true
  end

  def cache_status_css_class
    from_cache? ? "cache-hit" : "cache-miss"
  end
end
