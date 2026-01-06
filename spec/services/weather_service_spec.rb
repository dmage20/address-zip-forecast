require 'rails_helper'

RSpec.describe WeatherService do
  let(:geocoding_service) { instance_double(GeocodingService) }
  let(:weather_api) { instance_double(OpenWeatherMapService) }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:service) do
    described_class.new(
      geocoding_service: geocoding_service,
      weather_api: weather_api,
      cache: cache
    )
  end

  # Sample location data
  let(:location) do
    GeocodingService::Location.new(
      latitude: 38.8977,
      longitude: -77.0365,
      zip_code: '20500',
      formatted_address: '1600 Pennsylvania Avenue Northwest, Washington, DC 20500, USA'
    )
  end

  # Sample weather data
  let(:weather_data) do
    WeatherData.new(
      current_temp: 72.5,
      temp_min: 65.0,
      temp_max: 78.0,
      description: 'clear sky',
      icon: '01d',
      extended_forecast: [
        {
          date: Date.today,
          temp_min: 60.0,
          temp_max: 75.0,
          description: 'sunny',
          icon: '01d'
        }
      ]
    )
  end

  describe '#fetch_forecast' do
    context 'when address is valid and not cached' do
      let(:address) { '1600 Pennsylvania Avenue NW, Washington, DC' }

      before do
        allow(geocoding_service).to receive(:geocode)
          .with(address)
          .and_return(location)

        allow(weather_api).to receive(:fetch_weather)
          .with(38.8977, -77.0365)
          .and_return(weather_data)
      end

      it 'returns a ForecastResult object' do
        result = service.fetch_forecast(address)
        expect(result).to be_a(ForecastResult)
      end

      it 'geocodes the address' do
        expect(geocoding_service).to receive(:geocode).with(address)
        service.fetch_forecast(address)
      end

      it 'fetches weather data using coordinates' do
        expect(weather_api).to receive(:fetch_weather).with(38.8977, -77.0365)
        service.fetch_forecast(address)
      end

      it 'includes location in result' do
        result = service.fetch_forecast(address)
        expect(result.location).to eq(location)
      end

      it 'includes weather data in result' do
        result = service.fetch_forecast(address)
        expect(result.weather_data).to eq(weather_data)
      end

      it 'marks result as not cached' do
        result = service.fetch_forecast(address)
        expect(result.cached?).to be false
      end

      it 'stores result in cache' do
        service.fetch_forecast(address)
        cached_data = cache.read('forecast:20500:v1')
        expect(cached_data).not_to be_nil
      end

      it 'caches with correct TTL (30 minutes)' do
        # Test cache expiry using ActiveSupport::Testing::TimeHelpers
        service.fetch_forecast(address)

        # Data should be in cache now
        expect(cache.read('forecast:20500:v1')).not_to be_nil

        # Travel forward 29 minutes - should still be cached
        travel 29.minutes do
          expect(cache.read('forecast:20500:v1')).not_to be_nil
        end

        # Travel forward 31 minutes total - should be expired
        travel 31.minutes do
          expect(cache.read('forecast:20500:v1')).to be_nil
        end
      end
    end

    context 'when forecast is already cached' do
      let(:address) { '1600 Pennsylvania Avenue NW, Washington, DC' }

      before do
        # Pre-populate cache
        cache.write('forecast:20500:v1', {
          location: location.to_h,
          weather_data: weather_data.to_h
        }, expires_in: 30.minutes)

        allow(geocoding_service).to receive(:geocode)
          .with(address)
          .and_return(location)
      end

      it 'returns cached result' do
        result = service.fetch_forecast(address)
        expect(result).to be_a(ForecastResult)
      end

      it 'marks result as cached' do
        result = service.fetch_forecast(address)
        expect(result.cached?).to be true
      end

      it 'does not call weather API' do
        expect(weather_api).not_to receive(:fetch_weather)
        service.fetch_forecast(address)
      end

      it 'still geocodes address to get zip code' do
        expect(geocoding_service).to receive(:geocode).with(address)
        service.fetch_forecast(address)
      end

      it 'returns correct location data' do
        result = service.fetch_forecast(address)
        expect(result.location.zip_code).to eq('20500')
        expect(result.location.latitude).to eq(38.8977)
      end

      it 'returns correct weather data' do
        result = service.fetch_forecast(address)
        expect(result.weather_data.current_temp).to eq(73) # Rounded
      end
    end

    context 'when multiple addresses in same zip code' do
      let(:address1) { '1600 Pennsylvania Avenue NW, Washington, DC 20500' }
      let(:address2) { '1650 Pennsylvania Avenue NW, Washington, DC 20500' }

      let(:location2) do
        GeocodingService::Location.new(
          latitude: 38.8978, # Slightly different coordinates
          longitude: -77.0366,
          zip_code: '20500', # Same zip code
          formatted_address: '1650 Pennsylvania Avenue NW, Washington, DC 20500'
        )
      end

      before do
        # First address geocodes and fetches weather
        allow(geocoding_service).to receive(:geocode)
          .with(address1)
          .and_return(location)

        allow(weather_api).to receive(:fetch_weather)
          .with(38.8977, -77.0365)
          .and_return(weather_data)

        # Second address geocodes but uses cached weather
        allow(geocoding_service).to receive(:geocode)
          .with(address2)
          .and_return(location2)
      end

      it 'caches by zip code, not full address' do
        # First request - fetches and caches
        result1 = service.fetch_forecast(address1)
        expect(result1.cached?).to be false

        # Second request with different address but same zip - uses cache
        result2 = service.fetch_forecast(address2)
        expect(result2.cached?).to be true
      end

      it 'only calls weather API once for same zip code' do
        expect(weather_api).to receive(:fetch_weather).once
        service.fetch_forecast(address1)
        service.fetch_forecast(address2)
      end
    end

    context 'when address is invalid' do
      it 'raises AddressNotFoundError if geocoding returns nil' do
        allow(geocoding_service).to receive(:geocode)
          .with('invalid address')
          .and_return(nil)

        expect {
          service.fetch_forecast('invalid address')
        }.to raise_error(WeatherService::AddressNotFoundError, /not found/)
      end
    end

    context 'when geocoding service fails' do
      let(:address) { '123 Main St' }

      before do
        allow(geocoding_service).to receive(:geocode)
          .and_raise(Geocoder::Error, 'Service unavailable')
      end

      it 'raises ApiError' do
        expect {
          service.fetch_forecast(address)
        }.to raise_error(WeatherService::ApiError, /Geocoding service/)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Geocoding service error/)
        begin
          service.fetch_forecast(address)
        rescue WeatherService::ApiError
          # Expected
        end
      end
    end

    context 'when weather API fails' do
      let(:address) { '1600 Pennsylvania Ave NW' }

      before do
        allow(geocoding_service).to receive(:geocode)
          .with(address)
          .and_return(location)

        allow(weather_api).to receive(:fetch_weather)
          .and_raise(OpenWeatherMapService::ApiError, 'API temporarily unavailable')
      end

      it 'raises ApiError' do
        expect {
          service.fetch_forecast(address)
        }.to raise_error(WeatherService::ApiError, /API temporarily unavailable/)
      end
    end
  end

  describe 'cache key generation' do
    it 'includes zip code in cache key' do
      location = GeocodingService::Location.new(
        latitude: 38.8977,
        longitude: -77.0365,
        zip_code: '20500',
        formatted_address: 'Washington, DC'
      )
      key = service.send(:cache_key, location)
      expect(key).to include('20500')
    end

    it 'includes version in cache key' do
      location = GeocodingService::Location.new(
        latitude: 38.8977,
        longitude: -77.0365,
        zip_code: '20500',
        formatted_address: 'Washington, DC'
      )
      key = service.send(:cache_key, location)
      expect(key).to include('v1')
    end

    it 'has consistent format' do
      location = GeocodingService::Location.new(
        latitude: 40.7128,
        longitude: -74.0060,
        zip_code: '10001',
        formatted_address: 'New York, NY'
      )
      key = service.send(:cache_key, location)
      expect(key).to eq('forecast:10001:v1')
    end

    it 'handles UNKNOWN zip code with coordinate fallback' do
      location = GeocodingService::Location.new(
        latitude: 40.7128,
        longitude: -74.0060,
        zip_code: 'UNKNOWN',
        formatted_address: 'Some Location'
      )
      key = service.send(:cache_key, location)
      expect(key).to eq('forecast:lat_40.71_lon_-74.01:v1')
    end
  end

  describe 'constants' do
    it 'defines CACHE_TTL as 30 minutes' do
      expect(described_class::CACHE_TTL).to eq(30.minutes)
    end
  end

  describe 'default dependencies' do
    before do
      # Mock ENV variable for these tests
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENWEATHER_API_KEY').and_return('test_key')
    end

    it 'uses GeocodingService by default' do
      service = described_class.new
      expect(service.instance_variable_get(:@geocoding_service)).to be_a(GeocodingService)
    end

    it 'uses OpenWeatherMapService by default' do
      service = described_class.new
      expect(service.instance_variable_get(:@weather_api)).to be_a(OpenWeatherMapService)
    end

    it 'uses Rails.cache by default' do
      service = described_class.new
      expect(service.instance_variable_get(:@cache)).to eq(Rails.cache)
    end
  end
end
