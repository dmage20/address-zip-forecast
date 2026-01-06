# GeocodingService - Converts addresses to geographic coordinates and zip codes
#
# This service wraps the Geocoder gem to provide a clean interface for
# converting user-provided addresses into geographic data needed for weather lookups.
#
# Design Pattern: Adapter Pattern
# - Adapts the Geocoder gem's interface to our application's needs
# - Provides a consistent Location struct for other services
#
# Responsibility: Single Responsibility Principle
# - Only handles address-to-coordinates conversion
# - Does not make weather API calls or manage caching
#
# Usage:
#   service = GeocodingService.new
#   location = service.geocode("1600 Pennsylvania Avenue NW, Washington, DC")
#   # => #<struct GeocodingService::Location latitude=38.8977, longitude=-77.0365, ...>

class GeocodingService
  # Location value object to encapsulate geocoding results
  # Using a Struct provides immutability and clear data structure
  Location = Struct.new(:latitude, :longitude, :zip_code, :formatted_address, keyword_init: true) do
    def to_h
      {
        latitude: latitude,
        longitude: longitude,
        zip_code: zip_code,
        formatted_address: formatted_address
      }
    end
  end

  # Geocode an address to geographic coordinates and extract zip code
  #
  # @param address [String] The address to geocode (street address, city, state, or zip)
  # @return [Location, nil] Location object if found, nil if address is invalid or not found
  #
  # @example
  #   geocode("New York, NY")
  #   geocode("10001")
  #   geocode("1600 Pennsylvania Ave NW, Washington, DC 20500")
  def geocode(address)
    return nil if address.blank?

    # Use Geocoder gem to search for the address
    # Geocoder returns an array of results, we take the first (most relevant)
    # Restrict to US addresses only
    results = Geocoder.search(address, params: { countrycodes: "us" })

    # Return nil if no results found
    return nil if results.empty?

    result = results.first

    # Filter out overly broad locations (countries, states)
    # Check the addresstype from Nominatim
    address_type = result.data["addresstype"]
    return nil if [ "country", "state" ].include?(address_type)

    # Build and return our Location struct
    Location.new(
      latitude: result.latitude,
      longitude: result.longitude,
      zip_code: extract_zip_code(result),
      formatted_address: result.address
    )
  rescue Geocoder::Error => e
    # Log the error for debugging but don't crash the app
    # The calling service (WeatherService) will handle the nil response
    Rails.logger.error("Geocoding error for address '#{address}': #{e.message}")
    raise
  end

  private

  # Extract zip code from Geocoder result
  # Nominatim (OpenStreetMap) stores postal code in different places depending on the query
  #
  # @param result [Geocoder::Result] The Geocoder result object
  # @return [String] The postal/zip code, or 'UNKNOWN' if not found
  def extract_zip_code(result)
    # Try multiple sources for zip code:
    # Fall back to 'UNKNOWN' if not found
    result.postal_code ||
      result.data.dig("address", "postcode") ||
      "UNKNOWN"
  end
end
