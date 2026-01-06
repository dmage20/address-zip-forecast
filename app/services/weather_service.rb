# WeatherService - Main orchestrator for weather forecast functionality
#
# Design Pattern: Facade Pattern
# - Provides a simple interface to complex subsystems (geocoding, weather API, caching)
# - Coordinates multiple services to complete the forecast flow
#
# Responsibility: Single Responsibility Principle
# - Orchestrate the forecast fetching process
# - Manage caching strategy (30-minute TTL by location)
# - Handle errors and convert to user-friendly exceptions
#
# This service does NOT:
# - Make HTTP requests directly
# - Parse addresses or API responses
# - Contain business logic for geocoding or weather parsing
# - Persist forecast data beyond cache TTL (30 minutes)
#   * Cache is used for performance, not historical storage
#   * For historical data, a ForecastRecord model could be added to persist forecasts
#   * This would allow querying past weather data and trend analysis
#
# Usage:
#   service = WeatherService.new
#   result = service.fetch_forecast("1600 Pennsylvania Ave NW, Washington, DC")
#   # => #<ForecastResult location=..., weather_data=..., cached=false>

class WeatherService
  # Cache TTL - 30 minutes as per requirements
  CACHE_TTL = 30.minutes

  # Custom exception hierarchy for clear error handling
  class Error < StandardError; end
  class AddressNotFoundError < Error; end
  class ApiError < Error; end

  # Initialize the service with injectable dependencies
  #
  # @param geocoding_service [GeocodingService] Service for address geocoding
  # @param weather_api [OpenWeatherMapService] Service for weather API calls
  # @param cache [ActiveSupport::Cache::Store] Cache store (Solid Cache by default)
  def initialize(
    geocoding_service: GeocodingService.new,
    weather_api: OpenWeatherMapService.new,
    cache: Rails.cache
  )
    @geocoding_service = geocoding_service
    @weather_api = weather_api
    @cache = cache
  end

  # Fetch weather forecast for a given address
  #
  # The fetch_forecast method orchestrates the entire flow:
  # 1. Geocode address to get coordinates and zip code
  # 2. Check cache for existing forecast (by location: zip code or coordinates)
  # 3. If cache miss, fetch from weather API
  # 4. Store result in cache
  # 5. Return ForecastResult object
  #
  # @param address [String] The address to look up (full address, city, state, or zip)
  # @return [ForecastResult] Complete forecast result with cache indicator
  # @raise [AddressNotFoundError] if address cannot be geocoded
  # @raise [ApiError] if weather API fails
  #
  # @example
  #   fetch_forecast("New York, NY")
  #   fetch_forecast("10001")
  #   fetch_forecast("1600 Pennsylvania Avenue NW, Washington, DC 20500")
  def fetch_forecast(address)
    # Step 1: Geocode address to get location data
    location = @geocoding_service.geocode(address)
    raise AddressNotFoundError, "Address not found. Please verify and try again." unless location

    # Step 2: Check cache by location (zip code or coordinates)
    # Multiple addresses in the same zip code can share cached forecast
    # Falls back to coordinates when zip code is unavailable
    cached = cached_forecast(location)
    return cached if cached

    # Step 3: Cache miss - fetch fresh weather data from API
    weather_data = @weather_api.fetch_weather(location.latitude, location.longitude)

    # Step 4: Build result object
    result = ForecastResult.new(
      location: location,
      weather_data: weather_data,
      cached: false
    )

    # Step 5: Store in cache with 30-minute TTL
    store_forecast(location, result)

    result

  # Error handling: Convert low-level errors to our custom exceptions
  rescue Geocoder::Error => e
    # Geocoding service failed (network issue, rate limit, etc.)
    Rails.logger.error("Geocoding service error: #{e.message}")
    raise ApiError, "Geocoding service temporarily unavailable. Please try again later."

  rescue OpenWeatherMapService::ApiError => e
    # Weather API failed (already logged by OpenWeatherMapService)
    raise ApiError, e.message
  end

  private

  # Generate cache key for a location
  # Format: "forecast:{zip_code}:v1" or "forecast:lat_{lat}_lon_{lon}:v1"
  # The :v1 suffix allows for cache versioning if we change the data structure
  #
  # Falls back to coordinates if zip code is unknown to prevent cache collisions
  # between different locations without zip codes
  #
  # @param location [GeocodingService::Location] Location object
  # @return [String] Cache key
  def cache_key(location)
    if location.zip_code.present? && location.zip_code != "UNKNOWN"
      "forecast:#{location.zip_code}:v1"
    else
      # Use rounded coordinates for cache key when zip is unavailable
      # Round to 2 decimal places (~1km precision) for reasonable cache sharing
      lat = location.latitude.round(2)
      lon = location.longitude.round(2)
      "forecast:lat_#{lat}_lon_#{lon}:v1"
    end
  end

  # Retrieve forecast from cache
  #
  # @param location [GeocodingService::Location] Location object
  # @return [ForecastResult, nil] Cached forecast or nil if not found
  def cached_forecast(location)
    data = @cache.read(cache_key(location))
    return nil unless data

    # Reconstruct ForecastResult from cached hash
    # Use the from_cache class method which marks the result as cached
    ForecastResult.from_cache(data)
  end

  # Store forecast in cache with TTL
  #
  # @param location [GeocodingService::Location] Location object
  # @param result [ForecastResult] Forecast result to cache
  def store_forecast(location, result)
    @cache.write(
      cache_key(location),
      result.to_cache_hash,
      expires_in: CACHE_TTL
    )
  end
end
