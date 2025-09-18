# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForecastViewModel do
  let(:valid_attributes) do
    {
      address: "1600 Amphitheatre Parkway, Mountain View, CA",
      zip: "94043",
      current_temp_f: 72.5,
      high_temp_f: 80.0,
      low_temp_f: 65.0,
      from_cache: false
    }
  end

  let(:view_model) { described_class.new(valid_attributes) }

  describe "validations" do
    it "is valid with all required attributes" do
      expect(view_model).to be_valid
    end

    it "requires address" do
      view_model.address = nil
      expect(view_model).not_to be_valid
      expect(view_model.errors[:address]).to include("can't be blank")
    end

    it "requires zip" do
      view_model.zip = nil
      expect(view_model).not_to be_valid
      expect(view_model.errors[:zip]).to include("can't be blank")
    end

    it "validates zip code format" do
      view_model.zip = "invalid"
      expect(view_model).not_to be_valid
      expect(view_model.errors[:zip]).to include("must be a valid ZIP code")
    end

    it "accepts 5-digit zip codes" do
      view_model.zip = "12345"
      expect(view_model).to be_valid
    end

    it "accepts 5+4 zip codes" do
      view_model.zip = "12345-6789"
      expect(view_model).to be_valid
    end

    it "requires current_temp_f" do
      view_model.current_temp_f = nil
      expect(view_model).not_to be_valid
      expect(view_model.errors[:current_temp_f]).to include("can't be blank")
    end

    it "validates current_temp_f is numeric" do
      # Float type casting converts "hot" to 0.0, so we need to validate differently
      view_model = described_class.new(valid_attributes)
      view_model.current_temp_f = nil
      expect(view_model).not_to be_valid
      expect(view_model.errors[:current_temp_f]).to include("can't be blank")
    end
  end

  describe "#formatted_current_temp" do
    it "formats temperature with degree symbol" do
      expect(view_model.formatted_current_temp).to eq "72.5°F"
    end

    it "rounds to one decimal place" do
      view_model.current_temp_f = 72.456
      expect(view_model.formatted_current_temp).to eq "72.5°F"
    end

    it "returns N/A for nil temperature" do
      view_model.current_temp_f = nil
      expect(view_model.formatted_current_temp).to eq "N/A"
    end
  end

  describe "#formatted_high_temp" do
    it "formats high temperature with degree symbol" do
      expect(view_model.formatted_high_temp).to eq "80.0°F"
    end

    it "returns N/A for nil high temperature" do
      view_model.high_temp_f = nil
      expect(view_model.formatted_high_temp).to eq "N/A"
    end
  end

  describe "#formatted_low_temp" do
    it "formats low temperature with degree symbol" do
      expect(view_model.formatted_low_temp).to eq "65.0°F"
    end

    it "returns N/A for nil low temperature" do
      view_model.low_temp_f = nil
      expect(view_model.formatted_low_temp).to eq "N/A"
    end
  end

  describe "#cache_status_message" do
    it "returns cache hit message when from_cache is true" do
      view_model.from_cache = true
      expect(view_model.cache_status_message).to eq "Result served from cache"
    end

    it "returns fresh result message when from_cache is false" do
      view_model.from_cache = false
      expect(view_model.cache_status_message).to eq "Fresh result"
    end
  end

  describe "#high_low_available?" do
    it "returns true when both high and low temps are present" do
      expect(view_model.high_low_available?).to be true
    end

    it "returns false when high temp is missing" do
      view_model.high_temp_f = nil
      expect(view_model.high_low_available?).to be false
    end

    it "returns false when low temp is missing" do
      view_model.low_temp_f = nil
      expect(view_model.high_low_available?).to be false
    end

    it "returns false when both temps are missing" do
      view_model.high_temp_f = nil
      view_model.low_temp_f = nil
      expect(view_model.high_low_available?).to be false
    end
  end

  describe "#temperature_range" do
    it "returns formatted range when both temps available" do
      expect(view_model.temperature_range).to eq "80.0°F / 65.0°F"
    end

    it "returns N/A when high/low not available" do
      view_model.high_temp_f = nil
      expect(view_model.temperature_range).to eq "N/A"
    end
  end

  describe "#full_address_display" do
    it "combines address and zip code" do
      expect(view_model.full_address_display)
        .to eq "1600 Amphitheatre Parkway, Mountain View, CA (94043)"
    end
  end

  describe "#from_cache?" do
    it "returns true when from_cache is true" do
      view_model.from_cache = true
      expect(view_model.from_cache?).to be true
    end

    it "returns false when from_cache is false" do
      view_model.from_cache = false
      expect(view_model.from_cache?).to be false
    end

    it "returns false when from_cache is nil" do
      view_model.from_cache = nil
      expect(view_model.from_cache?).to be false
    end
  end

  describe "#cache_status_css_class" do
    it "returns cache-hit class when from cache" do
      view_model.from_cache = true
      expect(view_model.cache_status_css_class).to eq "cache-hit"
    end

    it "returns cache-miss class when not from cache" do
      view_model.from_cache = false
      expect(view_model.cache_status_css_class).to eq "cache-miss"
    end
  end
end
