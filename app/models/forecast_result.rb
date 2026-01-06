# ForecastResult - Value object representing complete forecast response
#
# Design Pattern: Value Object Pattern
# - Immutable object that combines location and weather data
# - No database persistence (Plain Old Ruby Object)
# - Frozen after creation to ensure immutability
#
# Responsibility:
# - Encapsulate complete forecast result (location + weather + cache status)
# - Provide serialization for caching
# - Track whether result came from cache
#
# This class does NOT:
# - Make API calls
# - Handle caching logic
# - Perform geocoding or weather fetching
#
# Usage:
#   result = ForecastResult.new(
#     location: geocoding_service.geocode("New York, NY"),
#     weather_data: weather_api.fetch_weather(40.7128, -74.0060),
#     cached: false
#   )
#   result.cached?  # => false

class ForecastResult
  attr_reader :location, :weather_data, :cached

  # Initialize a new ForecastResult object
  #
  # @param location [GeocodingService::Location] Location data (lat, lon, zip, address)
  # @param weather_data [WeatherData] Weather information
  # @param cached [Boolean] Whether this result came from cache (default: false)
  def initialize(location:, weather_data:, cached: false)
    @location = location
    @weather_data = weather_data
    @cached = cached

    # Freeze the object to make it immutable
    # Value objects should not be modified after creation
    freeze
  end

  # Check if this result came from cache
  #
  # @return [Boolean] true if cached, false if freshly fetched
  def cached?
    @cached
  end

  # Convert to hash for caching
  # Serializes the location and weather data for storage in Solid Cache
  #
  # @return [Hash] Hash representation for cache storage
  def to_cache_hash
    {
      location: location.to_h,
      weather_data: weather_data.to_h
    }
  end

  # Reconstruct from cached hash
  # This is used by WeatherService when retrieving from cache
  #
  # @param hash [Hash] Cached data hash
  # @return [ForecastResult] Reconstructed result marked as cached
  def self.from_cache(hash)
    new(
      location: GeocodingService::Location.new(**hash[:location]),
      weather_data: WeatherData.new(**hash[:weather_data]),
      cached: true
    )
  end
end
