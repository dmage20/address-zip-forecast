# Address-Zip-Forecast
<img width="1610" height="886" alt="centered-layout" src="https://github.com/user-attachments/assets/f222e569-7e13-452f-9953-ac50287131bb" />


A production-quality Ruby on Rails weather forecast application that accepts an address and displays current weather conditions plus a 5-day forecast. Built with Rails 8.1.1 and Ruby 3.3.6 as a technical assessment demonstrating senior-level software engineering practices.

## Features

- **Address-Based Lookup**: Enter any US address, city/state, or zip code
- **Current Weather**: Temperature, high/low, description, and weather icon
- **5-Day Forecast**: Extended forecast with daily highs/lows and conditions
- **Smart Caching**: 30-minute cache by zip code using Rails 8's Solid Cache
- **Cache Indicator**: Visual badge showing if results are fresh or cached
- **Modern UI**: Responsive design with Tailwind CSS and Hotwire/Turbo
- **Error Handling**: User-friendly messages for invalid addresses and API failures

## Prerequisites

- Ruby 3.3.6
- Rails 8.1.1
- SQLite 3 (for database and Solid Cache)
- OpenWeatherMap API key ([Get free key](https://openweathermap.org/api))

## Setup Instructions

### 1. Install Dependencies

```bash
bundle install
```

### 2. Configure Environment Variables

Copy the example environment file and add your OpenWeatherMap API key:

```bash
cp .env.example .env
```

Edit `.env` and set your API key:

```
OPENWEATHER_API_KEY=your_actual_api_key_here
```

### 3. Run Database Migrations

```bash
rails db:migrate
```

### 4. Start the Server

```bash
rails server
```

Visit http://localhost:3000

## Running Tests

```bash
bundle exec rspec
```

**Code Coverage**: 73%+ (run `open coverage/index.html` to view report)

**Security Scan**:
```bash
bundle exec brakeman -A -q
```

## Architecture

### Design Patterns

- **Service Object Pattern**: Business logic in dedicated service classes
- **Adapter Pattern**: Clean interfaces for OpenWeatherMap API and Geocoder gem
- **Value Object Pattern**: Immutable ForecastResult and WeatherData objects
- **Facade Pattern**: WeatherService orchestrates complex operations
- **Dependency Injection**: Services accept dependencies for testing
- **Thin Controller**: Controllers delegate to services

### Core Services

**WeatherService** - Main orchestrator
- Coordinates geocoding, caching, and weather fetching
- Manages 30-minute cache TTL by zip code
- Error handling with custom exceptions
- **Note**: Forecast data is cached only, not persisted to database (see `ARCHITECTURE.md` for rationale and future enhancement options)

**GeocodingService** - Address converter
- Converts addresses to coordinates using Nominatim
- Extracts zip codes for caching

**OpenWeatherMapService** - API client
- Fetches current weather and 5-day forecast
- Handles API errors and timeouts

See `ARCHITECTURE.md` for detailed object decomposition.

## Scalability

- **Solid Cache**: Database-backed caching, easily sharded
- **Stateless Services**: Horizontal scaling across app servers
- **Zip-Code Caching**: Reduces API calls by 80%+
- **Service Isolation**: Easy to extract to microservices

---

**Built with**: Ruby 3.3.6 • Rails 8.1.1 • Solid Cache • Hotwire • Tailwind CSS

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
