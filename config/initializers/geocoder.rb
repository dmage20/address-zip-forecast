# Geocoder configuration for address-to-coordinates conversion
# Uses Nominatim (OpenStreetMap) - free service, no API key required
#
# Geocoder gem documentation: https://github.com/alexreisner/geocoder

Geocoder.configure(
  # Use Nominatim (OpenStreetMap) as the geocoding provider
  lookup: :nominatim,
  # Timeout for geocoding requests (in seconds)
  timeout: 5,
  country_coude: :us,  # Restrict to US addresses for better accuracy
  # Nominatim requires a User-Agent header to identify the application
  # This helps them monitor usage and contact you if there are issues
  http_headers: {
    "User-Agent" => "AddressZipForecast/1.0 (weather-assessment)"
  },

  # Use HTTPS in prod/test; fall back to HTTP locally to dodge corp/CA issues
  use_https: !Rails.env.development?,

  # Nominatim-specific configuration
  nominatim: {
    host: "nominatim.openstreetmap.org"
  }
)
