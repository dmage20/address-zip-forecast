require 'rails_helper'
require 'webmock/rspec'

RSpec.describe OpenWeatherMapService do
  let(:api_key) { 'test_api_key_12345' }
  let(:service) { described_class.new(api_key: api_key) }
  let(:latitude) { 38.8977 }
  let(:longitude) { -77.0365 }

  # Sample API responses for mocking
  let(:current_weather_response) do
    {
      'main' => {
        'temp' => 72.5,
        'temp_min' => 65.2,
        'temp_max' => 78.8
      },
      'weather' => [
        {
          'description' => 'clear sky',
          'icon' => '01d'
        }
      ]
    }
  end

  let(:forecast_response) do
    {
      'list' => [
        # Day 1 - multiple entries
        {
          'dt_txt' => '2025-01-06 12:00:00',
          'main' => { 'temp_min' => 60.0, 'temp_max' => 75.0 },
          'weather' => [ { 'description' => 'sunny', 'icon' => '01d' } ]
        },
        {
          'dt_txt' => '2025-01-06 15:00:00',
          'main' => { 'temp_min' => 62.0, 'temp_max' => 78.0 },
          'weather' => [ { 'description' => 'sunny', 'icon' => '01d' } ]
        },
        # Day 2
        {
          'dt_txt' => '2025-01-07 12:00:00',
          'main' => { 'temp_min' => 58.0, 'temp_max' => 72.0 },
          'weather' => [ { 'description' => 'cloudy', 'icon' => '03d' } ]
        },
        # Day 3
        {
          'dt_txt' => '2025-01-08 12:00:00',
          'main' => { 'temp_min' => 55.0, 'temp_max' => 70.0 },
          'weather' => [ { 'description' => 'rainy', 'icon' => '10d' } ]
        },
        # Day 4
        {
          'dt_txt' => '2025-01-09 12:00:00',
          'main' => { 'temp_min' => 62.0, 'temp_max' => 76.0 },
          'weather' => [ { 'description' => 'partly cloudy', 'icon' => '02d' } ]
        },
        # Day 5
        {
          'dt_txt' => '2025-01-10 12:00:00',
          'main' => { 'temp_min' => 64.0, 'temp_max' => 80.0 },
          'weather' => [ { 'description' => 'clear', 'icon' => '01d' } ]
        }
      ]
    }
  end

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect { described_class.new(api_key: 'valid_key') }.not_to raise_error
      end
    end

    context 'without API key' do
      it 'raises ArgumentError when API key is nil' do
        expect {
          described_class.new(api_key: nil)
        }.to raise_error(ArgumentError, /API key not configured/)
      end

      it 'raises ArgumentError when API key is empty string' do
        expect {
          described_class.new(api_key: '')
        }.to raise_error(ArgumentError, /API key not configured/)
      end
    end

    context 'with default API key from ENV' do
      it 'uses OPENWEATHER_API_KEY environment variable' do
        allow(ENV).to receive(:[]).with('OPENWEATHER_API_KEY').and_return('env_key_12345')
        service = described_class.new
        expect(service.instance_variable_get(:@api_key)).to eq('env_key_12345')
      end
    end
  end

  describe '#fetch_weather' do
    before do
      # Stub current weather API call
      stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
        .with(query: hash_including(
          lat: latitude.to_s,
          lon: longitude.to_s,
          appid: api_key,
          units: 'imperial'
        ))
        .to_return(
          status: 200,
          body: current_weather_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Stub forecast API call
      stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
        .with(query: hash_including(
          lat: latitude.to_s,
          lon: longitude.to_s,
          appid: api_key,
          units: 'imperial',
          cnt: '40'
        ))
        .to_return(
          status: 200,
          body: forecast_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns a WeatherData object' do
      result = service.fetch_weather(latitude, longitude)
      expect(result).to be_a(WeatherData)
    end

    it 'fetches current temperature' do
      result = service.fetch_weather(latitude, longitude)
      expect(result.current_temp).to eq(73) # Rounded from 72.5
    end

    it 'fetches min and max temperatures' do
      result = service.fetch_weather(latitude, longitude)
      expect(result.temp_min).to eq(65) # Rounded from 65.2
      expect(result.temp_max).to eq(79) # Rounded from 78.8
    end

    it 'fetches weather description' do
      result = service.fetch_weather(latitude, longitude)
      expect(result.description).to eq('clear sky')
    end

    it 'fetches weather icon code' do
      result = service.fetch_weather(latitude, longitude)
      expect(result.icon).to eq('01d')
    end

    it 'fetches extended 5-day forecast' do
      result = service.fetch_weather(latitude, longitude)
      expect(result.extended_forecast).to be_an(Array)
      expect(result.extended_forecast.length).to eq(5)
    end

    it 'groups forecast by date and calculates daily min/max' do
      result = service.fetch_weather(latitude, longitude)
      day_one = result.extended_forecast.first

      expect(day_one[:date]).to eq(Date.parse('2025-01-06'))
      expect(day_one[:temp_min]).to eq(60.0) # Minimum temp for day 1
      expect(day_one[:temp_max]).to eq(78.0) # Maximum temp for day 1
      expect(day_one[:description]).to eq('sunny')
      expect(day_one[:icon]).to eq('01d')
    end
  end

  describe 'error handling' do
    context 'when current weather API returns 401 Unauthorized' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(
            lat: latitude.to_s,
            lon: longitude.to_s,
            appid: api_key
          ))
          .to_return(status: 401, body: { message: 'Invalid API key' }.to_json)
      end

      it 'raises ApiError' do
        expect {
          service.fetch_weather(latitude, longitude)
        }.to raise_error(OpenWeatherMapService::ApiError, /status 401/)
      end
    end

    context 'when forecast API returns 500 Internal Server Error' do
      before do
        # Stub successful current weather call
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: latitude.to_s, lon: longitude.to_s))
          .to_return(status: 200, body: current_weather_response.to_json)

        # Stub failed forecast call
        stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
          .with(query: hash_including(lat: latitude.to_s, lon: longitude.to_s))
          .to_return(status: 500, body: { message: 'Server error' }.to_json)
      end

      it 'raises ApiError' do
        expect {
          service.fetch_weather(latitude, longitude)
        }.to raise_error(OpenWeatherMapService::ApiError, /status 500/)
      end
    end

    context 'when network timeout occurs' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: latitude.to_s, lon: longitude.to_s))
          .to_timeout
      end

      it 'raises ApiError with friendly message' do
        allow(Rails.logger).to receive(:error)
        expect {
          service.fetch_weather(latitude, longitude)
        }.to raise_error(OpenWeatherMapService::ApiError, /temporarily unavailable/)
      end
    end

    context 'when socket error occurs' do
      before do
        stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
          .with(query: hash_including(lat: latitude.to_s, lon: longitude.to_s))
          .to_raise(SocketError.new('Failed to open TCP connection'))
      end

      it 'raises ApiError with friendly message' do
        allow(Rails.logger).to receive(:error)
        expect {
          service.fetch_weather(latitude, longitude)
        }.to raise_error(OpenWeatherMapService::ApiError, /temporarily unavailable/)
      end
    end
  end

  describe 'API query parameters' do
    it 'includes latitude in request' do
      stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
        .with(query: hash_including(lat: latitude.to_s))
        .to_return(
          status: 200,
          body: current_weather_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
        .with(query: hash_including(lat: latitude.to_s))
        .to_return(
          status: 200,
          body: forecast_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      service.fetch_weather(latitude, longitude)
    end

    it 'uses imperial units for Fahrenheit' do
      stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
        .with(query: hash_including(units: 'imperial'))
        .to_return(
          status: 200,
          body: current_weather_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
        .with(query: hash_including(units: 'imperial'))
        .to_return(
          status: 200,
          body: forecast_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      service.fetch_weather(latitude, longitude)
    end

    it 'includes API key in request' do
      stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
        .with(query: hash_including(appid: api_key))
        .to_return(
          status: 200,
          body: current_weather_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
        .with(query: hash_including(appid: api_key))
        .to_return(
          status: 200,
          body: forecast_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      service.fetch_weather(latitude, longitude)
    end
  end
end
