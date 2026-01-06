# WeatherData - Value object encapsulating weather information
#
# Design Pattern: Value Object Pattern
# - Immutable object that represents weather data
# - No database persistence (Plain Old Ruby Object)
# - Frozen after creation to ensure immutability
#
# Responsibility:
# - Encapsulate weather information in a structured format
# - Provide serialization for caching
# - Round temperatures to integers for display
#
# This class does NOT:
# - Make API calls
# - Handle caching
# - Perform geocoding
#
# Usage:
#   weather = WeatherData.new(
#     current_temp: 72.5,
#     temp_min: 65.2,
#     temp_max: 78.8,
#     description: 'clear sky',
#     icon: '01d',
#     extended_forecast: [...]
#   )
#   weather.current_temp  # => 73 (rounded)

class WeatherData
  attr_reader :current_temp, :temp_min, :temp_max, :description, :icon, :extended_forecast

  # Initialize a new WeatherData object
  #
  # @param current_temp [Float] Current temperature in Fahrenheit
  # @param temp_min [Float] Minimum temperature in Fahrenheit
  # @param temp_max [Float] Maximum temperature in Fahrenheit
  # @param description [String] Weather description (e.g., "clear sky")
  # @param icon [String] OpenWeatherMap icon code (e.g., "01d")
  # @param extended_forecast [Array<Hash>] 5-day forecast data
  def initialize(current_temp:, temp_min:, temp_max:, description:, icon:, extended_forecast:)
    # Round temperatures to integers for display
    # Fractional degrees don't add value for user-facing weather data
    @current_temp = current_temp.round
    @temp_min = temp_min.round
    @temp_max = temp_max.round
    @description = description
    @icon = icon
    @extended_forecast = extended_forecast

    # Freeze the object to make it immutable
    # This prevents accidental modification and signals value object semantics
    freeze
  end

  # Convert to hash for serialization (caching)
  #
  # @return [Hash] Hash representation of weather data
  def to_h
    {
      current_temp: current_temp,
      temp_min: temp_min,
      temp_max: temp_max,
      description: description,
      icon: icon,
      extended_forecast: extended_forecast
    }
  end
end
