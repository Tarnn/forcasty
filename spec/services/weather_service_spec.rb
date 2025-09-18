# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe WeatherService do
  let(:service) { described_class.new }
  let(:valid_payload) do
    {
      "current_weather" => { "temperature" => 72.4 },
      "daily" => {
        "temperature_2m_max" => [ 80.1 ],
        "temperature_2m_min" => [ 55.2 ]
      }
    }
  end

  before { WebMock.enable! }
  after { WebMock.disable! }

  describe "#fetch" do
    context "with valid coordinates and successful API response" do
      before do
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: valid_payload.to_json)
      end

      it "returns weather result with all temperature data" do
        result = service.fetch(lat: 37.7749, lon: -122.4194)

        expect(result).to be_a(WeatherService::Result)
        expect(result.current_temp_f).to eq 72.4
        expect(result.high_temp_f).to eq 80.1
        expect(result.low_temp_f).to eq 55.2
        expect(result.raw).to eq valid_payload
        expect(result).to be_valid
      end

      it "makes request with correct parameters" do
        service.fetch(lat: 40.7128, lon: -74.0060)

        expect(WebMock).to have_requested(:get, /api.open-meteo.com/)
          .with(query: hash_including({
            "latitude" => "40.7128",
            "longitude" => "-74.006",
            "current_weather" => "true",
            "temperature_unit" => "fahrenheit",
            "timezone" => "auto"
          }))
      end
    end

    context "with invalid coordinates" do
      it "raises ArgumentError for non-numeric latitude" do
        expect { service.fetch(lat: "invalid", lon: -122.4194) }
          .to raise_error(ArgumentError, "Coordinates must be numeric")
      end

      it "raises ArgumentError for non-numeric longitude" do
        expect { service.fetch(lat: 37.7749, lon: "invalid") }
          .to raise_error(ArgumentError, "Coordinates must be numeric")
      end

      it "raises ArgumentError for latitude out of range" do
        expect { service.fetch(lat: 91.0, lon: -122.4194) }
          .to raise_error(ArgumentError, "Coordinates out of valid range")
      end

      it "raises ArgumentError for longitude out of range" do
        expect { service.fetch(lat: 37.7749, lon: 181.0) }
          .to raise_error(ArgumentError, "Coordinates out of valid range")
      end
    end

    context "when API returns error status" do
      before do
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises APIError" do
        expect { service.fetch(lat: 1.0, lon: 2.0) }
          .to raise_error(WeatherService::APIError)
      end
    end

    context "when API request times out" do
      before do
        stub_request(:get, /api.open-meteo.com/).to_timeout
      end

      it "raises TimeoutError" do
        expect { service.fetch(lat: 1.0, lon: 2.0) }
          .to raise_error(WeatherService::APIError)
      end
    end

    context "when API returns invalid JSON" do
      before do
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: "invalid json")
      end

      it "raises InvalidResponseError" do
        expect { service.fetch(lat: 1.0, lon: 2.0) }
          .to raise_error(WeatherService::InvalidResponseError, /Invalid JSON response/)
      end
    end

    context "when API returns malformed response" do
      before do
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: '"just a string"')
      end

      it "raises InvalidResponseError for non-object response" do
        expect { service.fetch(lat: 1.0, lon: 2.0) }
          .to raise_error(WeatherService::InvalidResponseError, /Expected JSON object/)
      end
    end

    context "when API returns response without current_weather" do
      before do
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: '{"daily": {}}')
      end

      it "raises InvalidResponseError" do
        expect { service.fetch(lat: 1.0, lon: 2.0) }
          .to raise_error(WeatherService::InvalidResponseError, /Missing current_weather/)
      end
    end

    context "with minimal valid response" do
      let(:minimal_payload) do
        { "current_weather" => { "temperature" => 65.0 } }
      end

      before do
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: minimal_payload.to_json)
      end

      it "handles missing daily temperatures gracefully" do
        result = service.fetch(lat: 1.0, lon: 2.0)

        expect(result.current_temp_f).to eq 65.0
        expect(result.high_temp_f).to be_nil
        expect(result.low_temp_f).to be_nil
      end
    end
  end

  describe "Result" do
    let(:result) do
      WeatherService::Result.new(
        current_temp_f: 72.5,
        high_temp_f: 80.0,
        low_temp_f: 65.0,
        raw: {}
      )
    end

    describe "#valid?" do
      it "returns true when current temperature is numeric" do
        expect(result).to be_valid
      end

      it "returns false when current temperature is nil" do
        invalid_result = WeatherService::Result.new(
          current_temp_f: nil,
          high_temp_f: 80.0,
          low_temp_f: 65.0,
          raw: {}
        )
        expect(invalid_result).not_to be_valid
      end

      it "returns false when current temperature is not numeric" do
        invalid_result = WeatherService::Result.new(
          current_temp_f: "hot",
          high_temp_f: 80.0,
          low_temp_f: 65.0,
          raw: {}
        )
        expect(invalid_result).not_to be_valid
      end
    end

    describe "#current_temp_display" do
      it "formats temperature with degree symbol" do
        expect(result.current_temp_display).to eq "72.5°F"
      end

      it "returns N/A for nil temperature" do
        result_with_nil = WeatherService::Result.new(
          current_temp_f: nil,
          high_temp_f: nil,
          low_temp_f: nil,
          raw: {}
        )
        expect(result_with_nil.current_temp_display).to eq "N/A"
      end
    end
  end

  describe "initialization" do
    it "accepts custom HTTP client" do
      custom_client = class_double("CustomHTTP")
      service = described_class.new(http_client: custom_client)
      expect(service).to be_a(WeatherService)
    end

    it "accepts custom base URL" do
      custom_url = "https://custom-weather-api.com/v1/forecast"
      service = described_class.new(base_url: custom_url)
      expect(service).to be_a(WeatherService)
    end

    it "accepts custom timeout" do
      service = described_class.new(timeout: 30)
      expect(service).to be_a(WeatherService)
    end
  end
end
