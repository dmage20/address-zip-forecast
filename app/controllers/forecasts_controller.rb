# ForecastsController - Handles weather forecast requests
#
# Design Pattern: Thin Controller Pattern
# - Minimal business logic in controller
# - Delegates to WeatherService for all forecast operations
# - Focuses on HTTP concerns (parameters, responses, error handling)
#
# Responsibility:
# - Accept user input (address)
# - Coordinate with WeatherService
# - Render appropriate views or error responses
# - Handle HTTP-specific error codes
#
# RESTful Design:
# - index: Display search form - initial page
# - show: Process search and display results
#
# Error Handling:
# - 422 Unprocessable Entity: Invalid address or location too broad
# - 503 Service Unavailable: API failures

class ForecastsController < ApplicationController
  # GET /
  # Display the address search form
  def index
    # @result will be nil initially
    # @error will be set if there's a validation error from a failed submission
  end

  # GET /forecast?address=...
  # POST /forecast
  # Process address and display weather forecast
  #
  # Supports both GET (for direct URL access) and POST (from form submission)
  # Uses Turbo Frame for async updates without full page reload
  def show
    address = params[:address]

    # Basic input validation
    if address.blank?
      @error = "Please enter an address."
      render :index, status: :unprocessable_entity
      return
    end

    # Fetch forecast using service layer
    @result = WeatherService.new.fetch_forecast(address)

    # Respond with appropriate format
    # Turbo will update only the forecast_results frame
    respond_to do |format|
      format.html # renders show.html.erb
      format.turbo_stream # supports Turbo Frame updates
    end

  # Error handling with user-friendly messages and appropriate HTTP status codes
  rescue WeatherService::AddressNotFoundError => e
    # User entered an address that couldn't be geocoded
    # This includes: invalid addresses, typos, or overly broad locations (country/state)
    # which are filtered out by featureType='settlement' parameter
    # HTTP 422: The request was well-formed but semantically incorrect
    @error = "We couldn't find that address. Please enter a specific US location like a city name, street address, or zip code."
    render :error, status: :unprocessable_entity

  rescue WeatherService::ApiError => e
    # Weather API or geocoding service is down
    # HTTP 503: Service temporarily unavailable
    Rails.logger.error("Weather service error: #{e.message}")
    @error = "We're having trouble fetching weather data right now. Please try again in a few moments."
    render :error, status: :service_unavailable
  end
end
