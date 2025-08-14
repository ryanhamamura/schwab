## [Unreleased]

### Added
- Nothing yet

### Changed
- Nothing yet

### Deprecated
- Nothing yet

### Removed
- Nothing yet

### Fixed
- Nothing yet

### Security
- Nothing yet

## [0.2.0] - 2025-08-14

### Added
- **Comprehensive Account Management System**
  - `Accounts.get_accounts` - Fetch all accounts with optional field filtering
  - `Accounts.get_account` - Get detailed single account information
  - `Accounts.get_positions` - Retrieve account positions with P&L data
  - `Accounts.get_transactions` - Get transaction history with filtering
  - `Accounts.get_orders` - Fetch orders with status and date filtering  
  - `Accounts.get_all_orders` - Get orders across all accounts
  - `Accounts.preview_order` - Preview order costs and requirements before placement
  - `Accounts.get_account_numbers` - Retrieve account number mappings
  - `Accounts.get_user_preferences` - Get user trading preferences

- **Encrypted Account Number System**
  - `AccountNumberResolver` - Thread-safe resolver for plain to encrypted account numbers
  - Automatic caching with lazy loading and mutex synchronization
  - Transparent usage - developers use plain account numbers, SDK handles encryption
  - Uses `/accounts/accountNumbers` endpoint to fetch account mappings
  - Hash detection logic to distinguish encrypted vs plain account numbers

- **Resource Object Wrappers**
  - Configurable response format (`:hash` or `:resource`)
  - Sawyer-style resource objects with method access (e.g., `account.account_number`)
  - Automatic type coercion for dates, times, numbers, and booleans
  - Nested object wrapping with identity preservation
  - Hash-style access still available alongside method access

- **Enhanced Configuration**
  - `response_format` option to choose between hash and resource object responses
  - Comprehensive validation for all configuration parameters
  - Backward compatibility maintained with hash format as default

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
  - `bin/test_account_numbers.rb` - Comprehensive account endpoint testing
  - `bin/debug_market_data.rb` - Debug response structures
  - `bin/test_oauth_with_credentials.rb` - Test OAuth token refresh
  - `bin/oauth_test.rb` - Interactive OAuth flow testing

### Changed
- **Account API Integration**
  - All account endpoints now use encrypted account numbers transparently
  - Fixed nested response structure handling (positions under `securitiesAccount`)
  - Enhanced date formatting to preserve full ISO-8601 timestamps
  - Added proper error handling with response body preservation for debugging

- **HTTP Client Enhancements**
  - Resource class support in all HTTP methods (GET, POST, PUT, DELETE, PATCH)
  - Response wrapping based on configuration format
  - Automatic resource class determination from response data
  - Enhanced error handling with preserved response bodies

- API endpoint routing to support different versioning schemes
  - OAuth endpoints use `/v1/oauth/...`
  - Market data endpoints use `/marketdata/v1/...`
  - Account endpoints use `/trader/v1/accounts/...`
- Connection builder now uses base URL without version prefix
- OAuth endpoints hardcoded to `/v1` regardless of configuration

### Fixed
- **Account API Issues**
  - Positions endpoint now correctly extracts from `securitiesAccount.positions`
  - Transactions endpoint includes required `types` parameter
  - Date format handling preserves full ISO-8601 timestamps
  - Order preview integration with existing accounts module

- **Code Quality**
  - All RuboCop style issues resolved
  - Duplicate method definitions removed
  - Proper DateTime handling without deprecated methods
  - String formatting using `format()` instead of `%` operator

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
