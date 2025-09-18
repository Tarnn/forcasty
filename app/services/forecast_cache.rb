# frozen_string_literal: true

# Manages caching of weather forecasts by ZIP code
class ForecastCache
  DEFAULT_TTL = 30.minutes
  CACHE_PREFIX = "forecast"

  class CacheError < StandardError; end

  def initialize(cache: Rails.cache, ttl: DEFAULT_TTL)
    @cache = cache
    @ttl = ttl
    validate_cache_store
  end

  # Get cached data for ZIP code
  def fetch(zip)
    validate_zip_code(zip)

    begin
      @cache.read(build_cache_key(zip))
    rescue => e
      Rails.logger.error("Cache read failed for zip #{zip}: #{e.message}")
      raise CacheError, "Failed to read from cache: #{e.message}"
    end
  end

  # Store data in cache for ZIP code
  def write(zip, value)
    validate_zip_code(zip)
    return if value.nil?

    begin
      cache_key = build_cache_key(zip)
      @cache.write(cache_key, value, expires_in: @ttl)
      Rails.logger.info("Cached forecast for zip #{zip} (expires in #{@ttl.inspect})")
    rescue => e
      Rails.logger.error("Cache write failed for zip #{zip}: #{e.message}")
      raise CacheError, "Failed to write to cache: #{e.message}"
    end
  end

  # Get from cache or execute block and cache result
  def fetch_or_store(zip)
    validate_zip_code(zip)
    raise ArgumentError, "Block required" unless block_given?

    cached_result = fetch(zip)
    if cached_result
      Rails.logger.info("Cache hit for zip #{zip}")
      return [ cached_result, true ]
    end

    Rails.logger.info("Cache miss for zip #{zip} - fetching fresh data")
    fresh_result = yield
    write(zip, fresh_result)
    [ fresh_result, false ]
  end

  def delete(zip)
    validate_zip_code(zip)

    begin
      @cache.delete(build_cache_key(zip))
      Rails.logger.info("Cleared cache for zip #{zip}")
    rescue => e
      Rails.logger.error("Cache delete failed for zip #{zip}: #{e.message}")
      raise CacheError, "Failed to delete from cache: #{e.message}"
    end
  end

  def exists?(zip)
    validate_zip_code(zip)
    @cache.exist?(build_cache_key(zip))
  end

  private

  def validate_cache_store
    required_methods = %i[read write delete exist?]
    missing_methods = required_methods.reject { |method| @cache.respond_to?(method) }

    unless missing_methods.empty?
      raise ArgumentError, "Cache store missing methods: #{missing_methods.join(', ')}"
    end
  end

  def validate_zip_code(zip)
    if zip.to_s.strip.empty?
      raise ArgumentError, "ZIP code cannot be blank"
    end

    unless zip.to_s.match?(/\A\d{5}(-\d{4})?\z/)
      Rails.logger.warn("Non-standard ZIP code format: #{zip}")
    end
  end

  def build_cache_key(zip)
    normalized_zip = zip.to_s.strip.upcase
    "#{CACHE_PREFIX}:#{normalized_zip}"
  end
end
