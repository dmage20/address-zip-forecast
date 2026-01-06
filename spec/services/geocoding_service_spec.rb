require 'rails_helper'

RSpec.describe GeocodingService do
  let(:service) { described_class.new }

  describe '#geocode' do
    context 'with a valid address' do
      let(:address) { '1600 Pennsylvania Avenue NW, Washington, DC 20500' }
      let(:mock_result) do
        double(
          'Geocoder::Result',
          latitude: 38.8977,
          longitude: -77.0365,
          postal_code: '20500',
          address: '1600 Pennsylvania Avenue Northwest, Washington, DC 20500, USA',
          data: { 'address' => { 'postcode' => '20500' }, 'addresstype' => 'building' }
        )
      end

      before do
        allow(Geocoder).to receive(:search).with(address, params: { countrycodes: 'us' }).and_return([ mock_result ])
      end

      it 'returns a Location object' do
        result = service.geocode(address)
        expect(result).to be_a(GeocodingService::Location)
      end

      it 'extracts latitude correctly' do
        result = service.geocode(address)
        expect(result.latitude).to eq(38.8977)
      end

      it 'extracts longitude correctly' do
        result = service.geocode(address)
        expect(result.longitude).to eq(-77.0365)
      end

      it 'extracts zip code from postal_code attribute' do
        result = service.geocode(address)
        expect(result.zip_code).to eq('20500')
      end

      it 'includes formatted address' do
        result = service.geocode(address)
        expect(result.formatted_address).to eq('1600 Pennsylvania Avenue Northwest, Washington, DC 20500, USA')
      end
    end

    context 'when zip code is in data hash instead of postal_code attribute' do
      let(:address) { 'New York, NY' }
      let(:mock_result) do
        double(
          'Geocoder::Result',
          latitude: 40.7128,
          longitude: -74.0060,
          postal_code: nil, # Not available directly
          address: 'New York, NY, USA',
          data: { 'address' => { 'postcode' => '10001' }, 'addresstype' => 'city' }
        )
      end

      before do
        allow(Geocoder).to receive(:search).with(address, params: { countrycodes: 'us' }).and_return([ mock_result ])
      end

      it 'extracts zip code from data hash' do
        result = service.geocode(address)
        expect(result.zip_code).to eq('10001')
      end
    end

    context 'when zip code is not available' do
      let(:address) { 'Some vague location' }
      let(:mock_result) do
        double(
          'Geocoder::Result',
          latitude: 40.0,
          longitude: -74.0,
          postal_code: nil,
          address: 'Some Location, USA',
          data: { 'address' => {}, 'addresstype' => 'hamlet' } # No postcode in data
        )
      end

      before do
        allow(Geocoder).to receive(:search).with(address, params: { countrycodes: 'us' }).and_return([ mock_result ])
      end

      it 'returns UNKNOWN as zip code' do
        result = service.geocode(address)
        expect(result.zip_code).to eq('UNKNOWN')
      end
    end

    context 'with an invalid address' do
      it 'returns nil for blank address' do
        result = service.geocode('')
        expect(result).to be_nil
      end

      it 'returns nil for nil address' do
        result = service.geocode(nil)
        expect(result).to be_nil
      end

      it 'returns nil when Geocoder finds no results' do
        allow(Geocoder).to receive(:search).with('invalid address', params: { countrycodes: 'us' }).and_return([])
        result = service.geocode('invalid address')
        expect(result).to be_nil
      end
    end

    context 'when Geocoder raises an error' do
      let(:address) { '123 Main St' }

      before do
        allow(Geocoder).to receive(:search).and_raise(Geocoder::Error, 'Service unavailable')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Geocoding error for address '#{address}'/)
        expect { service.geocode(address) }.to raise_error(Geocoder::Error)
      end

      it 're-raises the Geocoder::Error' do
        allow(Rails.logger).to receive(:error)
        expect { service.geocode(address) }.to raise_error(Geocoder::Error, 'Service unavailable')
      end
    end

    context 'when address is overly broad (state or country)' do
      it 'returns nil for state-level results' do
        mock_result = double(
          'Geocoder::Result',
          latitude: 32.3182,
          longitude: -86.9023,
          postal_code: nil,
          address: 'Alabama, United States',
          data: { 'addresstype' => 'state' }
        )
        allow(Geocoder).to receive(:search).with('Alabama', params: { countrycodes: 'us' }).and_return([mock_result])

        result = service.geocode('Alabama')
        expect(result).to be_nil
      end

      it 'returns nil for country-level results' do
        mock_result = double(
          'Geocoder::Result',
          latitude: 39.8283,
          longitude: -98.5795,
          postal_code: nil,
          address: 'United States',
          data: { 'addresstype' => 'country' }
        )
        allow(Geocoder).to receive(:search).with('United States', params: { countrycodes: 'us' }).and_return([mock_result])

        result = service.geocode('United States')
        expect(result).to be_nil
      end

      it 'accepts city-level results' do
        mock_result = double(
          'Geocoder::Result',
          latitude: 33.5186,
          longitude: -86.8104,
          postal_code: '35203',
          address: 'Birmingham, Alabama, United States',
          data: { 'addresstype' => 'city', 'address' => { 'postcode' => '35203' } }
        )
        allow(Geocoder).to receive(:search).with('Birmingham, Alabama', params: { countrycodes: 'us' }).and_return([mock_result])

        result = service.geocode('Birmingham, Alabama')
        expect(result).to be_a(GeocodingService::Location)
        expect(result.formatted_address).to eq('Birmingham, Alabama, United States')
      end
    end
  end

  describe 'Location struct' do
    let(:location) do
      described_class::Location.new(
        latitude: 38.8977,
        longitude: -77.0365,
        zip_code: '20500',
        formatted_address: '1600 Pennsylvania Ave NW, Washington, DC 20500'
      )
    end

    it 'provides keyword initialization' do
      expect(location.latitude).to eq(38.8977)
      expect(location.longitude).to eq(-77.0365)
      expect(location.zip_code).to eq('20500')
      expect(location.formatted_address).to eq('1600 Pennsylvania Ave NW, Washington, DC 20500')
    end

    describe '#to_h' do
      it 'converts to hash with all attributes' do
        hash = location.to_h
        expect(hash).to eq({
          latitude: 38.8977,
          longitude: -77.0365,
          zip_code: '20500',
          formatted_address: '1600 Pennsylvania Ave NW, Washington, DC 20500'
        })
      end
    end
  end
end
