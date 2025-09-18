# frozen_string_literal: true

require "rails_helper"

RSpec.describe GeocodingService do
  let(:service) { described_class.new(geocoder: geocoder) }
  let(:geocoder) { class_double(Geocoder) }

  describe "#geocode" do
    context "with valid address" do
      let(:fake_result) do
        instance_double(
          "GeocodeResult",
          latitude: 37.422,
          longitude: -122.084,
          postal_code: "94043",
          data: {}
        )
      end

      before do
        allow(geocoder).to receive(:search)
          .with("1600 Amphitheatre Parkway, Mountain View, CA")
          .and_return([ fake_result ])
      end

      it "returns result with coordinates and zip" do
        result = service.geocode("1600 Amphitheatre Parkway, Mountain View, CA")

        expect(result).to be_a(GeocodingService::Result)
        expect(result.latitude).to eq 37.422
        expect(result.longitude).to eq -122.084
        expect(result.zip).to eq "94043"
        expect(result).to be_valid
      end
    end

    context "with postal code in data field" do
      let(:fake_result) do
        instance_double(
          "GeocodeResult",
          latitude: 40.7128,
          longitude: -74.0060,
          postal_code: nil,
          data: { "address" => { "postcode" => "10001" } }
        )
      end

      before do
        allow(geocoder).to receive(:search).and_return([ fake_result ])
      end

      it "extracts zip from data.address.postcode" do
        result = service.geocode("New York, NY")
        expect(result.zip).to eq "10001"
      end
    end

    context "with blank or empty address" do
      it "returns nil for empty string" do
        expect(service.geocode("")).to be_nil
      end

      it "returns nil for whitespace-only string" do
        expect(service.geocode("   ")).to be_nil
      end

      it "returns nil for nil input" do
        expect(service.geocode(nil)).to be_nil
      end
    end

    context "when geocoder returns no results" do
      before do
        allow(geocoder).to receive(:search).and_return([])
      end

      it "returns nil" do
        expect(service.geocode("nonexistent address")).to be_nil
      end
    end

    context "when geocoder returns result without postal code" do
      let(:fake_result) do
        instance_double(
          "GeocodeResult",
          latitude: 1.0,
          longitude: 2.0,
          postal_code: nil,
          data: {}
        )
      end

      before do
        allow(geocoder).to receive(:search).and_return([ fake_result ])
      end

      it "returns nil" do
        expect(service.geocode("address without zip")).to be_nil
      end
    end

    context "when geocoder raises an exception" do
      before do
        allow(geocoder).to receive(:search).and_raise(StandardError, "Network error")
      end

      it "raises GeocodingError" do
        expect { service.geocode("test address") }
          .to raise_error(GeocodingService::GeocodingError, /Unable to geocode address/)
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)

        expect { service.geocode("test address") }
          .to raise_error(GeocodingService::GeocodingError)

        expect(Rails.logger).to have_received(:error)
          .with(/Geocoding failed for address 'test address'/)
      end
    end
  end

  describe "Result" do
    it "defines immutable result object" do
      result = GeocodingService::Result.new(latitude: 1.0, longitude: 2.0, zip: "12345")

      expect(result.latitude).to eq 1.0
      expect(result.longitude).to eq 2.0
      expect(result.zip).to eq "12345"
    end

    describe "#valid?" do
      it "returns true when all fields are present" do
        result = GeocodingService::Result.new(latitude: 1.0, longitude: 2.0, zip: "12345")
        expect(result).to be_valid
      end

      it "returns false when latitude is missing" do
        result = GeocodingService::Result.new(latitude: nil, longitude: 2.0, zip: "12345")
        expect(result).not_to be_valid
      end

      it "returns false when longitude is missing" do
        result = GeocodingService::Result.new(latitude: 1.0, longitude: nil, zip: "12345")
        expect(result).not_to be_valid
      end

      it "returns false when zip is missing" do
        result = GeocodingService::Result.new(latitude: 1.0, longitude: 2.0, zip: nil)
        expect(result).not_to be_valid
      end
    end
  end
end
