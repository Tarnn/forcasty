# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForecastCache do
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:cache) { described_class.new(cache: cache_store, ttl: 1.minute) }
  let(:sample_data) { { current_temp_f: 72.5, high_temp_f: 80.0, low_temp_f: 65.0 } }

  describe "#fetch" do
    context "when data exists in cache" do
      before { cache.write("12345", sample_data) }

      it "returns cached data" do
        expect(cache.fetch("12345")).to eq sample_data
      end
    end

    context "when data does not exist in cache" do
      it "returns nil" do
        expect(cache.fetch("99999")).to be_nil
      end
    end

    context "with invalid zip code" do
      it "raises ArgumentError for blank zip" do
        expect { cache.fetch("") }
          .to raise_error(ArgumentError, "ZIP code cannot be blank")
      end

      it "raises ArgumentError for nil zip" do
        expect { cache.fetch(nil) }
          .to raise_error(ArgumentError, "ZIP code cannot be blank")
      end
    end

    context "when cache store raises exception" do
      let(:failing_cache) { instance_double("Cache") }
      let(:cache_with_failing_store) { described_class.new(cache: failing_cache) }

      before do
        allow(failing_cache).to receive(:respond_to?).and_return(true)
        allow(failing_cache).to receive(:read).and_raise(StandardError, "Cache error")
      end

      it "raises CacheError" do
        expect { cache_with_failing_store.fetch("12345") }
          .to raise_error(ForecastCache::CacheError, /Failed to read from cache/)
      end
    end
  end

  describe "#write" do
    it "stores data with TTL" do
      cache.write("12345", sample_data)
      expect(cache.fetch("12345")).to eq sample_data
    end

    it "does not store nil values" do
      cache.write("12345", nil)
      expect(cache.fetch("12345")).to be_nil
    end

    it "logs cache write" do
      allow(Rails.logger).to receive(:info)
      cache.write("12345", sample_data)
      expect(Rails.logger).to have_received(:info)
        .with(/Cached forecast for zip 12345/)
    end

    context "with invalid zip code" do
      it "raises ArgumentError for blank zip" do
        expect { cache.write("", sample_data) }
          .to raise_error(ArgumentError, "ZIP code cannot be blank")
      end
    end

    context "when cache store raises exception" do
      let(:failing_cache) { instance_double("Cache") }
      let(:cache_with_failing_store) { described_class.new(cache: failing_cache) }

      before do
        allow(failing_cache).to receive(:respond_to?).and_return(true)
        allow(failing_cache).to receive(:write).and_raise(StandardError, "Cache error")
      end

      it "raises CacheError" do
        expect { cache_with_failing_store.write("12345", sample_data) }
          .to raise_error(ForecastCache::CacheError, /Failed to write to cache/)
      end
    end
  end

  describe "#fetch_or_store" do
    context "when data exists in cache" do
      before { cache.write("12345", sample_data) }

      it "returns cached data with from_cache=true" do
        allow(Rails.logger).to receive(:info)
        result, from_cache = cache.fetch_or_store("12345") { { temp: 99 } }

        expect(result).to eq sample_data
        expect(from_cache).to be true
        expect(Rails.logger).to have_received(:info).with(/Cache hit for zip 12345/)
      end

      it "does not execute the block" do
        block_executed = false
        cache.fetch_or_store("12345") { block_executed = true }
        expect(block_executed).to be false
      end
    end

    context "when data does not exist in cache" do
      it "executes block and stores result with from_cache=false" do
        allow(Rails.logger).to receive(:info)
        result, from_cache = cache.fetch_or_store("99999") { sample_data }

        expect(result).to eq sample_data
        expect(from_cache).to be false
        expect(cache.fetch("99999")).to eq sample_data
        expect(Rails.logger).to have_received(:info).with(/Cache miss for zip 99999/)
      end
    end

    context "without block" do
      it "raises ArgumentError" do
        expect { cache.fetch_or_store("12345") }
          .to raise_error(ArgumentError, "Block required")
      end
    end
  end

  describe "#delete" do
    before { cache.write("12345", sample_data) }

    it "removes data from cache" do
      expect(cache.fetch("12345")).to eq sample_data
      cache.delete("12345")
      expect(cache.fetch("12345")).to be_nil
    end

    it "logs cache deletion" do
      allow(Rails.logger).to receive(:info)
      cache.delete("12345")
      expect(Rails.logger).to have_received(:info).with(/Cleared cache for zip 12345/)
    end
  end

  describe "#exists?" do
    context "when data exists" do
      before { cache.write("12345", sample_data) }

      it "returns true" do
        expect(cache.exists?("12345")).to be true
      end
    end

    context "when data does not exist" do
      it "returns false" do
        expect(cache.exists?("99999")).to be false
      end
    end
  end

  describe "initialization" do
    it "accepts custom TTL" do
      custom_cache = described_class.new(ttl: 5.minutes)
      expect(custom_cache).to be_a(ForecastCache)
    end

    it "validates cache store has required methods" do
      invalid_cache = Object.new
      expect { described_class.new(cache: invalid_cache) }
        .to raise_error(ArgumentError, /Cache store missing methods/)
    end

    it "uses default TTL when not specified" do
      default_cache = described_class.new(cache: cache_store)
      expect(default_cache).to be_a(ForecastCache)
    end
  end

  describe "zip code validation" do
    context "with valid US ZIP codes" do
      it "accepts 5-digit ZIP" do
        expect { cache.fetch("12345") }.not_to raise_error
      end

      it "accepts 5+4 ZIP code" do
        expect { cache.fetch("12345-6789") }.not_to raise_error
      end
    end

    context "with non-standard ZIP codes" do
      it "logs warning for non-standard format but continues" do
        allow(Rails.logger).to receive(:warn)
        expect { cache.fetch("ABC123") }.not_to raise_error
        expect(Rails.logger).to have_received(:warn)
          .with(/Non-standard ZIP code format: ABC123/)
      end
    end
  end

  describe "cache key generation" do
    it "normalizes zip codes" do
      cache.write(" 12345 ", sample_data)
      expect(cache.fetch("12345")).to eq sample_data
    end

    it "converts to uppercase" do
      cache.write("abc12", sample_data)
      expect(cache.fetch("ABC12")).to eq sample_data
    end

    it "uses consistent prefix" do
      # This is a bit of a white-box test, but ensures consistency
      cache_instance = described_class.new(cache: cache_store)
      key1 = cache_instance.send(:build_cache_key, "12345")
      key2 = cache_instance.send(:build_cache_key, "12345")
      expect(key1).to eq key2
      expect(key1).to start_with("forecast:")
    end
  end
end
