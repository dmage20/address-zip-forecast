require 'rails_helper'

RSpec.feature 'Weather Forecast Lookup', type: :feature do
  # Mock services to avoid real API calls
  let(:geocoding_service) { instance_double(GeocodingService) }
  let(:weather_service) { instance_double(WeatherService) }

  before do
    allow(GeocodingService).to receive(:new).and_return(geocoding_service)
    allow(WeatherService).to receive(:new).and_return(weather_service)
  end

  scenario 'User successfully looks up weather for a valid city' do
    # Setup mock location
    location = GeocodingService::Location.new(
      latitude: 34.0522,
      longitude: -118.2437,
      zip_code: '90001',
      formatted_address: 'Los Angeles, California, United States'
    )

    # Setup mock weather data
    weather_data = WeatherData.new(
      current_temp: 72,
      temp_min: 65,
      temp_max: 78,
      description: 'clear sky',
      icon: '01d',
      extended_forecast: [
        { date: Date.today + 1, temp_min: 66, temp_max: 79, description: 'sunny', icon: '01d' },
        { date: Date.today + 2, temp_min: 67, temp_max: 80, description: 'sunny', icon: '01d' }
      ]
    )

    # Setup mock forecast result
    forecast_result = ForecastResult.new(
      location: location,
      weather_data: weather_data,
      cached: false
    )

    # Mock the service call
    allow(weather_service).to receive(:fetch_forecast).with('Los Angeles').and_return(forecast_result)

    # Visit the page
    visit root_path

    # Verify we're on the forecast page
    expect(page).to have_content('Weather Forecast Lookup')

    # Fill in the address
    fill_in 'Enter an address:', with: 'Los Angeles'

    # Submit the form
    click_button 'Get Forecast'

    # Verify weather results appear in the turbo frame
    within '#forecast_results' do
      expect(page).to have_content('Los Angeles, California, United States')
      expect(page).to have_content('Zip Code: 90001')
      expect(page).to have_content('72°F')
      expect(page).to have_content('clear sky')
      expect(page).to have_content('High: 78°F')
      expect(page).to have_content('Low: 65°F')
      expect(page).to have_content('Fresh data')
      expect(page).to have_content('5-Day Forecast')
    end
  end

  scenario 'User enters an invalid address and sees error message' do
    # Mock the service to raise AddressNotFoundError
    allow(weather_service).to receive(:fetch_forecast)
      .with('asdfasdfasdf')
      .and_raise(WeatherService::AddressNotFoundError)

    # Visit the page
    visit root_path

    # Fill in invalid address
    fill_in 'Enter an address:', with: 'asdfasdfasdf'

    # Submit the form
    click_button 'Get Forecast'

    # Verify error message appears in the turbo frame (not outside!)
    within '#forecast_results' do
      expect(page).to have_content('Error')
      expect(page).to have_content("We couldn't find that address")
      expect(page).to have_content('Please enter a specific US location')
      expect(page).to have_link('Try Another Address')
    end
  end

  scenario 'User enters a state name and sees error message' do
    # Mock the service to raise AddressNotFoundError (state is rejected by geocoding)
    allow(weather_service).to receive(:fetch_forecast)
      .with('Alabama')
      .and_raise(WeatherService::AddressNotFoundError)

    # Visit the page
    visit root_path

    # Fill in state name
    fill_in 'Enter an address:', with: 'Alabama'

    # Submit the form
    click_button 'Get Forecast'

    # Verify error message appears
    within '#forecast_results' do
      expect(page).to have_content('Error')
      expect(page).to have_content("We couldn't find that address")
      expect(page).to have_content('Please enter a specific US location')
    end
  end

  scenario 'User sees cached result indicator for cached forecast' do
    # Setup mock location
    location = GeocodingService::Location.new(
      latitude: 40.7128,
      longitude: -74.0060,
      zip_code: '10001',
      formatted_address: 'New York, NY, United States'
    )

    # Setup mock weather data
    weather_data = WeatherData.new(
      current_temp: 55,
      temp_min: 50,
      temp_max: 60,
      description: 'cloudy',
      icon: '04d',
      extended_forecast: [
        { date: Date.today + 1, temp_min: 51, temp_max: 61, description: 'cloudy', icon: '04d' }
      ]
    )

    # Setup mock forecast result with cached: true
    forecast_result = ForecastResult.new(
      location: location,
      weather_data: weather_data,
      cached: true
    )

    # Mock the service call
    allow(weather_service).to receive(:fetch_forecast).with('New York, NY').and_return(forecast_result)

    # Visit and submit
    visit root_path
    fill_in 'Enter an address:', with: 'New York, NY'
    click_button 'Get Forecast'

    # Verify cached indicator appears
    within '#forecast_results' do
      expect(page).to have_content('Cached result (updated within last 30 minutes)')
      expect(page).to have_content('New York, NY, United States')
    end
  end

  scenario 'User sees API error message when weather service is unavailable' do
    # Mock the service to raise ApiError
    allow(weather_service).to receive(:fetch_forecast)
      .with('Miami')
      .and_raise(WeatherService::ApiError, 'Weather service temporarily unavailable')

    # Visit the page
    visit root_path

    # Fill in address
    fill_in 'Enter an address:', with: 'Miami'

    # Submit the form
    click_button 'Get Forecast'

    # Verify service error message appears
    within '#forecast_results' do
      expect(page).to have_content('Error')
      expect(page).to have_content("We're having trouble fetching weather data")
      expect(page).to have_content('Please try again in a few moments')
    end
  end
end
