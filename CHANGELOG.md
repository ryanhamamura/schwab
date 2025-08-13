## [Unreleased]

### Added
- Market Data API endpoints
  - `MarketData.get_quotes` - Fetch quotes for multiple symbols
  - `MarketData.get_quote` - Get detailed quote for single symbol
  - `MarketData.get_quote_history` - Retrieve price history/candles
  - `MarketData.get_movers` - Track market movers by index
  - `MarketData.get_market_hours` - Get market session information
- Automatic token refresh via `TokenManager`
  - Auto-refreshes tokens when they expire in < 5 minutes
  - Shared across all test scripts for consistent token handling
- Test scripts for development
  - `bin/test_market_data.rb` - Test all market data endpoints
  - `bin/debug_market_data.rb` - Debug response structures
  - `bin/test_oauth_with_credentials.rb` - Test OAuth token refresh
  - `bin/oauth_test.rb` - Interactive OAuth flow testing

### Changed
- API endpoint routing to support different versioning schemes
  - OAuth endpoints use `/v1/oauth/...`
  - Market data endpoints use `/marketdata/v1/...`
  - Future trading endpoints will use `/trader/v1/...`
- Connection builder now uses base URL without version prefix
- OAuth endpoints hardcoded to `/v1` regardless of configuration

### Fixed
- Test suite compatibility with new URL structure
- RuboCop compliance for all code
- VCR cassette recording for OAuth refresh tokens

## [0.1.0] - 2025-08-12

- Initial release
- Core OAuth 2.0 authentication with Authorization Code flow
- HTTP client with Faraday middleware stack
- Exception-only error handling
- Thread-safe token refresh
- Configuration management
- Full test coverage with RSpec
