# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe "Forecasts", type: :request do
  let(:sample_weather_payload) do
    {
      "current_weather" => { "temperature" => 72.5 },
      "daily" => {
        "temperature_2m_max" => [ 80.0 ],
        "temperature_2m_min" => [ 65.0 ]
      }
    }
  end

  let(:geocoder_result) do
    instance_double(
      "GeocodeResult",
      latitude: 37.422,
      longitude: -122.084,
      postal_code: "94043",
      data: {}
    )
  end

  before { WebMock.enable! }
  after { WebMock.disable! }

  describe "GET /" do
    it "renders the forecast form" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weather Forecast")
      expect(response.body).to include("Enter Location")
    end
  end

  describe "GET /forecasts/new" do
    it "renders the forecast form" do
      get "/forecasts/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weather Forecast")
    end
  end

  describe "POST /forecasts" do
    context "with valid address and successful API calls" do
      before do
        allow(Geocoder).to receive(:search).and_return([ geocoder_result ])
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: sample_weather_payload.to_json)
      end

      it "displays weather forecast with fresh result indicator" do
        post "/forecasts", params: { forecast: { address: "1600 Amphitheatre Parkway" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Weather Forecast")
        expect(response.body).to include("1600 Amphitheatre Parkway (94043)")
        expect(response.body).to include("72.5°F")
        expect(response.body).to include("80.0°F")
        expect(response.body).to include("65.0°F")
        expect(response.body).to include("Fresh result")
      end

      it "displays cached result on subsequent request" do
        # Use a shared memory cache for this test
        cache_store = ActiveSupport::Cache::MemoryStore.new
        allow(Rails).to receive(:cache).and_return(cache_store)
        
        # First request - should be fresh
        post "/forecasts", params: { forecast: { address: "1600 Amphitheatre Parkway" } }
        expect(response.body).to include("Fresh result")
        
        # Second request with same ZIP should hit cache
        post "/forecasts", params: { forecast: { address: "Different address same ZIP" } }
        expect(response.body).to include("Result served from cache")
      end

      it "makes weather API call with correct parameters" do
        post "/forecasts", params: { forecast: { address: "Test Address" } }

        expect(WebMock).to have_requested(:get, /api.open-meteo.com/)
          .with(query: hash_including({
            "latitude" => "37.422",
            "longitude" => "-122.084",
            "current_weather" => "true",
            "temperature_unit" => "fahrenheit"
          }))
      end
    end

    context "with blank address" do
      it "renders form with error message" do
        post "/forecasts", params: { forecast: { address: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Please enter an address")
      end
    end

    context "with missing address parameter" do
      it "renders form with error message" do
        post "/forecasts", params: { forecast: {} }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Please enter an address")
      end
    end

    context "when geocoding fails" do
      before do
        allow(Geocoder).to receive(:search).and_return([])
      end

      it "renders form with geocoding error" do
        post "/forecasts", params: { forecast: { address: "Unknown Address" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Address not found")
      end
    end

    context "when geocoding service raises exception" do
      before do
        # Mock the controller's geocoding_service method to raise the exception
        allow_any_instance_of(ForecastsController).to receive(:geocoding_service) do
          geocoding_service = instance_double(GeocodingService)
          allow(geocoding_service).to receive(:geocode)
            .and_raise(GeocodingService::GeocodingError, "Service unavailable")
          geocoding_service
        end
      end

      it "renders form with service error" do
        post "/forecasts", params: { forecast: { address: "Test Address" } }

        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to include("Unable to process the address")
      end
    end

    context "when weather API is unavailable" do
      before do
        allow(Geocoder).to receive(:search).and_return([ geocoder_result ])
        stub_request(:get, /api.open-meteo.com/).to_return(status: 500)
      end

      it "renders form with weather service error" do
        post "/forecasts", params: { forecast: { address: "Test Address" } }

        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to include("Unable to retrieve weather data")
      end
    end

    context "when weather API times out" do
      before do
        allow(Geocoder).to receive(:search).and_return([ geocoder_result ])
        stub_request(:get, /api.open-meteo.com/).to_timeout
      end

      it "renders form with timeout error" do
        post "/forecasts", params: { forecast: { address: "Test Address" } }

        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to include("Unable to retrieve weather data")
      end
    end

    context "when cache service fails" do
      before do
        allow(Geocoder).to receive(:search).and_return([ geocoder_result ])
        stub_request(:get, /api.open-meteo.com/)
          .to_return(status: 200, body: sample_weather_payload.to_json)

        # Mock cache failure
        allow_any_instance_of(ForecastCache)
          .to receive(:fetch_or_store)
          .and_raise(ForecastCache::CacheError, "Cache unavailable")
      end

      it "continues processing despite cache error" do
        # The application should continue working even if cache fails
        # This tests graceful degradation
        expect(Rails.logger).to receive(:warn).with(/Cache error/)

        post "/forecasts", params: { forecast: { address: "Test Address" } }

        # Should still work, just without caching
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "routing" do
    it "routes root to forecasts#new" do
      get "/"
      expect(response).to have_http_status(:ok)
    end

    it "routes /forecasts/new to forecasts#new" do
      get "/forecasts/new"
      expect(response).to have_http_status(:ok)
    end

    it "routes POST /forecasts to forecasts#create" do
      allow(Geocoder).to receive(:search).and_return([])
      post "/forecasts", params: { forecast: { address: "test" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "redirects /forecast to root" do
      get "/forecast"
      expect(response).to redirect_to("/")
    end
  end
end
