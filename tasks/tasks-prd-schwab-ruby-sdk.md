# Tasks for Schwab Ruby SDK

## Relevant Files

- `lib/schwab.rb` - Main module file (exists, needs expansion)
- `lib/schwab/version.rb` - Version constant (exists)
- `lib/schwab/client.rb` - Main client class (to be created)
- `lib/schwab/oauth.rb` - OAuth helper methods (to be created)
- `lib/schwab/configuration.rb` - Configuration management (to be created)
- `lib/schwab/error.rb` - Error hierarchy (to be created)
- `lib/schwab/connection.rb` - Faraday HTTP setup (to be created)
- `lib/schwab/api/market_data.rb` - Market data endpoints (to be created)
- `lib/schwab/api/accounts.rb` - Account endpoints (to be created)
- `lib/schwab/api/trading.rb` - Trading endpoints (to be created)
- `spec/schwab/client_spec.rb` - Client tests (to be created)
- `spec/schwab/oauth_spec.rb` - OAuth tests (to be created)
- `spec/support/vcr.rb` - VCR configuration (to be created)
- `schwab.gemspec` - Gem specification (exists, needs dependencies)
- `Gemfile` - Development dependencies (exists, needs additions)

## Notes

- Follow the phased implementation approach from the PRD
- Use RSpec for testing with VCR for API recording
- Follow Shopify's RuboCop style guide (already configured)
- No built-in token storage - user manages tokens
- Exception-only error handling (Ruby idiom)
- Thread-safe implementation required
- Test using `bundle exec rspec`

## Tasks

- [ ] 1. Set up core dependencies and project structure
  - [ ] 1.1 Add required gems to schwab.gemspec: faraday (~> 2.0), oauth2 (~> 2.0), multi_json (~> 1.15), sawyer (~> 0.9)
  - [ ] 1.2 Add development dependencies to Gemfile: vcr, webmock, pry, yard, simplecov
  - [ ] 1.3 Run `bundle install` to install all dependencies
  - [ ] 1.4 Create the lib/schwab directory structure: api/, middleware/, resources/
  - [ ] 1.5 Set up spec/support directory with vcr.rb configuration file
  - [ ] 1.6 Configure VCR in spec/support/vcr.rb with cassette library path and filter sensitive data
  - [ ] 1.7 Update spec/spec_helper.rb to require VCR support and configure RSpec
  - [ ] 1.8 Create a .env.example file with SCHWAB_CLIENT_ID, SCHWAB_CLIENT_SECRET, SCHWAB_REDIRECT_URI placeholders
  - [ ] 1.9 Add dotenv gem to Gemfile for development environment variable loading
  - [ ] 1.10 Update .gitignore to exclude .env and VCR cassettes with sensitive data

- [ ] 2. Implement OAuth authentication foundation
  - [ ] 2.1 Create lib/schwab/oauth.rb with Schwab::OAuth module
  - [ ] 2.2 Implement OAuth.authorization_url method to generate Schwab authorization URL with proper parameters
  - [ ] 2.3 Implement OAuth.get_token method to exchange authorization code for access/refresh tokens
  - [ ] 2.4 Implement OAuth.refresh_token method to get new access token using refresh token
  - [ ] 2.5 Create lib/schwab/configuration.rb with Configuration class for storing client_id, client_secret, redirect_uri, api_base_url
  - [ ] 2.6 Add Schwab.configure class method in lib/schwab.rb to set global configuration
  - [ ] 2.7 Implement configuration validation to ensure required OAuth parameters are present
  - [ ] 2.8 Create spec/schwab/oauth_spec.rb with tests for authorization_url generation
  - [ ] 2.9 Add tests for OAuth.get_token with VCR cassette recording
  - [ ] 2.10 Add tests for OAuth.refresh_token with VCR cassette recording
  - [ ] 2.11 Create spec/schwab/configuration_spec.rb to test configuration validation and defaults

- [ ] 3. Build HTTP client layer with Faraday
  - [ ] 3.1 Create lib/schwab/connection.rb with Connection module for Faraday setup
  - [ ] 3.2 Implement Connection.build method to create Faraday instance with middleware stack
  - [ ] 3.3 Add OAuth2 token injection middleware to automatically add Authorization header
  - [ ] 3.4 Create lib/schwab/middleware/authentication.rb for token injection middleware
  - [ ] 3.5 Add request/response JSON encoding middleware using multi_json
  - [ ] 3.6 Create lib/schwab/middleware/rate_limit.rb for handling 429 responses with retry logic
  - [ ] 3.7 Implement exponential backoff strategy in rate limit middleware (max 3 retries)
  - [ ] 3.8 Add request/response logging middleware with configurable log levels
  - [ ] 3.9 Create lib/schwab/client.rb with Client class and initialize method accepting access_token
  - [ ] 3.10 Implement Client#connection method to lazily initialize Faraday connection
  - [ ] 3.11 Add Client support for auto_refresh option with on_token_refresh callback
  - [ ] 3.12 Implement thread-safe token refresh using Mutex when auto_refresh is enabled
  - [ ] 3.13 Create spec/schwab/connection_spec.rb to test Faraday middleware stack
  - [ ] 3.14 Add spec/schwab/client_spec.rb with tests for client initialization and configuration

- [ ] 4. Create error handling system
  - [ ] 4.1 Create lib/schwab/error.rb with base Schwab::Error class inheriting from StandardError
  - [ ] 4.2 Define Schwab::ApiError as base class for all API-related errors with status and response_body attributes
  - [ ] 4.3 Create Schwab::AuthenticationError for 401 responses
  - [ ] 4.4 Create Schwab::AuthorizationError for 403 responses
  - [ ] 4.5 Create Schwab::NotFoundError for 404 responses
  - [ ] 4.6 Create Schwab::RateLimitError for 429 responses with retry_after attribute
  - [ ] 4.7 Create Schwab::ServerError for 5xx responses
  - [ ] 4.8 Create Schwab::TokenExpiredError as subclass of AuthenticationError
  - [ ] 4.9 Implement error response parsing to extract error messages from Schwab API responses
  - [ ] 4.10 Create lib/schwab/middleware/error_handler.rb to raise appropriate exceptions based on response status
  - [ ] 4.11 Add error handler middleware to Faraday stack in Connection module
  - [ ] 4.12 Create spec/schwab/error_spec.rb with tests for each error class
  - [ ] 4.13 Add tests for error message extraction and response body preservation

- [ ] 5. Implement basic market data API methods
  - [ ] 5.1 Create lib/schwab/api/market_data.rb module with MarketData methods
  - [ ] 5.2 Include MarketData module in Client class
  - [ ] 5.3 Implement Client#get_quote(symbol) method to fetch single stock quote
  - [ ] 5.4 Add request method in Client to handle GET/POST/PUT/DELETE with path and params
  - [ ] 5.5 Configure Sawyer to return Resource objects with dot-notation access
  - [ ] 5.6 Implement Client#get_quotes(symbols) to fetch multiple quotes in one request
  - [ ] 5.7 Add Client#get_price_history with parameters: symbol, period_type, period, frequency_type, frequency
  - [ ] 5.8 Implement Client#get_option_chain with symbol, contract_type, strike_count parameters
  - [ ] 5.9 Add Client#get_market_hours with market_type and date parameters
  - [ ] 5.10 Create spec/schwab/api/market_data_spec.rb with test for get_quote
  - [ ] 5.11 Add VCR cassettes for each market data endpoint test
  - [ ] 5.12 Test response objects have dot-notation access (e.g., quote.symbol, quote.last_price)
  - [ ] 5.13 Add integration test that authenticates and fetches a real quote (marked as pending by default)