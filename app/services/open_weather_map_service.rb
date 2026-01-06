# OpenWeatherMapService - Fetches weather data from OpenWeatherMap API
#
# This service handles all interactions with the OpenWeatherMap API,
# including fetching current weather and 5-day forecast data.
#
# Design Pattern: Adapter Pattern
# - Adapts the OpenWeatherMap API to our application's needs
# - Provides a clean interface that returns WeatherData objects
#
# Responsibility: Single Responsibility Principle
# - Only handles OpenWeatherMap API communication
# - Does not handle geocoding or caching
#
# Error Handling:
# - Raises custom ApiError for all API failures
# - Logs errors for debugging
# - Validates API key on initialization (fail fast)
#
# Usage:
#   service = OpenWeatherMapService.new
#   weather_data = service.fetch_weather(38.8977, -77.0365)
#   # => #<WeatherData current_temp=72, temp_min=65, temp_max=78, ...>

class OpenWeatherMapService
  include HTTParty
  base_uri "https://api.openweathermap.org"

  # Custom exception for API errors
  # Provides clear error handling for calling code (WeatherService)
  class ApiError < StandardError; end

  # Initialize the service with an API key
  #
  # @param api_key [String] OpenWeatherMap API key (defaults to ENV variable or Rails credentials)
  # @raise [ArgumentError] if API key is not configured
  def initialize(api_key: ENV["OPENWEATHER_API_KEY"] || Rails.application.credentials.openweather_api_key)
    @api_key = api_key
    raise ArgumentError, "OpenWeatherMap API key not configured. Set OPENWEATHER_API_KEY environment variable." if @api_key.blank?
  end

  # Fetch current weather and 5-day forecast for given coordinates
  #
  # @param latitude [Float] Geographic latitude
  # @param longitude [Float] Geographic longitude
  # @return [WeatherData] Object containing current and forecast weather data
  # @raise [ApiError] if API request fails
  #
  # @example
  #   fetch_weather(38.8977, -77.0365)
  def fetch_weather(latitude, longitude)
    current = fetch_current_weather(latitude, longitude)
    forecast = fetch_forecast(latitude, longitude)

    # Build WeatherData object from API responses
    WeatherData.new(
      current_temp: current["main"]["temp"],
      temp_min: current["main"]["temp_min"],
      temp_max: current["main"]["temp_max"],
      description: current["weather"].first["description"],
      icon: current["weather"].first["icon"],
      extended_forecast: parse_extended_forecast(forecast)
    )
  rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
    # Catch all HTTP/network errors and wrap in our custom exception
    Rails.logger.error("OpenWeatherMap API error: #{e.class} - #{e.message}")
    raise ApiError, "Weather service temporarily unavailable. Please try again later."
  end

  private

  # Fetch current weather from OpenWeatherMap API
  #
  # @param lat [Float] Latitude
  # @param lon [Float] Longitude
  # @return [Hash] Parsed JSON response from API
  # @raise [ApiError] if API returns non-200 status
  def fetch_current_weather(lat, lon)
    response = self.class.get("/data/2.5/weather", query: {
      lat: lat,
      lon: lon,
      appid: @api_key,
      units: "imperial" # Fahrenheit for temperatures
    })

    # Check for HTTP errors (4xx, 5xx status codes)
    unless response.success?
      raise ApiError, "OpenWeatherMap API returned status #{response.code}: #{response.message}"
    end

    response.parsed_response
  end

  # Fetch 5-day forecast from OpenWeatherMap API
  # Returns forecast data in 3-hour intervals
  #
  # @param lat [Float] Latitude
  # @param lon [Float] Longitude
  # @return [Hash] Parsed JSON response from API
  # @raise [ApiError] if API returns non-200 status
  def fetch_forecast(lat, lon)
    response = self.class.get("/data/2.5/forecast", query: {
      lat: lat,
      lon: lon,
      appid: @api_key,
      units: "imperial",
      cnt: 40 # Get 40 data points (5 days * 8 intervals per day)
    })

    unless response.success?
      raise ApiError, "OpenWeatherMap API returned status #{response.code}: #{response.message}"
    end

    response.parsed_response
  end

  # Parse extended forecast from API response
  # Groups forecast data by day and extracts daily high/low temperatures
  #
  # The API returns data in 3-hour intervals. We group by date and find
  # the min/max temperatures for each day.
  #
  # @param forecast_data [Hash] Raw API response from /forecast endpoint
  # @return [Array<Hash>] Array of daily forecast hashes with :date, :temp_min, :temp_max, etc.
  def parse_extended_forecast(forecast_data)
    # Group forecast entries by date
    forecast_data["list"]
      .group_by { |entry| Date.parse(entry["dt_txt"]) }
      .map do |date, entries|
        {
          date: date,
          temp_min: entries.map { |e| e["main"]["temp_min"] }.min,
          temp_max: entries.map { |e| e["main"]["temp_max"] }.max,
          description: entries.first["weather"].first["description"],
          icon: entries.first["weather"].first["icon"]
        }
      end
      .first(5) # Return only 5 days
  end
end
