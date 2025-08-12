# PRD: Schwab Ruby SDK

## Introduction/Overview
The Schwab Ruby SDK is a client library that provides Ruby developers with easy, idiomatic access to the Charles Schwab API for trading, market data, and portfolio management. The SDK will handle OAuth 2.0 authentication, automatic token refresh, rate limiting, and provide a clean Ruby interface following established patterns from successful libraries like Stripe, Octokit, and the OAuth2 gem.

## Goals
1. Provide a Ruby-idiomatic interface to all Charles Schwab API endpoints
2. Handle OAuth 2.0 Authorization Code flow with automatic token refresh
3. Support both global configuration and per-client configuration options
4. Implement robust error handling with custom exception classes
5. Provide comprehensive testing support including VCR cassettes and sandbox mode
6. Ensure thread-safety for multi-threaded applications
7. Minimize external dependencies while maintaining functionality
8. Support automatic rate limit handling with configurable retry strategies

## User Stories
1. **As a Ruby developer**, I want to authenticate with Schwab's OAuth 2.0 flow so that I can access protected API endpoints
2. **As a trading application developer**, I want to place and manage orders programmatically so that I can automate trading strategies
3. **As a portfolio manager**, I want to retrieve account positions and balances so that I can track portfolio performance
4. **As a market data consumer**, I want to fetch real-time quotes and historical prices so that I can analyze market trends
5. **As a developer**, I want automatic token refresh so that I don't have to manually handle token expiration
6. **As a testing engineer**, I want to record and replay API interactions so that I can test without hitting the live API
7. **As a multi-account user**, I want to manage multiple Schwab accounts with different configurations so that I can separate concerns

## Functional Requirements

### Core Architecture
1. **Client Class** - Main entry point using instance-based pattern (not singleton)
   - Support multiple simultaneous clients with different configurations
   - Thread-safe operation for concurrent requests
   - Lazy initialization of resources

2. **Configuration System**
   - Global configuration via `Schwab.configure` block
   - Per-client configuration overrides
   - Support for environment variables (SCHWAB_CLIENT_ID, SCHWAB_CLIENT_SECRET, etc.)
   - Configuration validation on initialization

3. **OAuth 2.0 Authentication**
   - Authorization Code flow implementation (PKCE support planned for future)
   - Helper methods for OAuth flow (authorization URL, token exchange)
   - Token refresh helper method (user manages storage)
   - Optional automatic token refresh with callback
   - No built-in token storage (user responsibility)
   - Clear token expiry information in responses
   - Thread-safe token refresh when auto-refresh is enabled

4. **HTTP Client Layer**
   - Built on Faraday for extensibility
   - Middleware stack for:
     - OAuth2 token injection
     - Optional automatic token refresh with callback
     - Request/response logging (configurable)
     - Rate limit handling
     - Retry logic with exponential backoff
   - JSON request/response handling with multi_json

5. **Response Handling**
   - Return Sawyer::Resource objects (like Octokit) for dot-notation access
   - Preserve original response metadata (headers, status codes)
   - Support raw JSON mode via configuration option
   - Pagination helpers for list endpoints

6. **Error Handling**
   - Custom exception hierarchy inheriting from Schwab::Error
   - Specific exceptions for different error types:
     - Schwab::AuthenticationError (401)
     - Schwab::AuthorizationError (403)
     - Schwab::RateLimitError (429)
     - Schwab::NotFoundError (404)
     - Schwab::ServerError (5xx)
   - Include request/response details in exceptions
   - Optional error response mode (return error objects instead of raising)

7. **API Resource Coverage**
   - **Market Data API**
     - Get quotes (single and multiple symbols)
     - Get price history with configurable parameters
     - Get option chains
     - Get market hours
   - **Trading API**
     - Place orders (market, limit, stop, etc.)
     - Cancel/replace orders
     - Get order status and history
   - **Account API**
     - Get account details and balances
     - Get positions
     - Get transactions
   - **Future additions**: Streaming API support

8. **Rate Limiting**
   - Automatic retry with exponential backoff for 429 responses
   - Configurable max retry attempts (default: 3)
   - Optional rate limit pre-emption based on response headers
   - Built-in request throttling to stay within limits

9. **Testing Support**
   - VCR integration for recording/replaying HTTP interactions
   - Built-in test helpers for mocking responses
   - Sandbox environment support via configuration
   - Factory patterns for generating test data

10. **Logging and Debugging**
    - Configurable logger (defaults to Ruby Logger)
    - Debug mode for detailed request/response logging
    - Performance instrumentation hooks
    - Request ID tracking for debugging

## Non-Goals (Out of Scope)
1. OAuth 2.0 server implementation (client only)
2. WebSocket/streaming API support (initial release)
3. Financial calculations or portfolio analytics
4. Tax reporting or document generation
5. Direct database integrations
6. Built-in caching beyond token storage
7. GraphQL or non-REST API support
8. Mobile SDK features (biometric auth, etc.)

## Design Considerations

### API Interface Design
```ruby
# Global configuration (optional, for defaults)
Schwab.configure do |config|
  config.client_id = ENV['SCHWAB_CLIENT_ID']
  config.client_secret = ENV['SCHWAB_CLIENT_SECRET']
  config.redirect_uri = ENV['SCHWAB_REDIRECT_URI']
  config.logger = Rails.logger
  config.api_base_url = 'https://api.schwabapi.com' # Default, can override for future API versions
end

# OAuth flow helpers
auth_url = Schwab::OAuth.authorization_url(
  client_id: ENV['SCHWAB_CLIENT_ID'],
  redirect_uri: ENV['SCHWAB_REDIRECT_URI']
)

# Exchange authorization code for tokens
token_response = Schwab::OAuth.get_token(
  code: params[:code],
  client_id: ENV['SCHWAB_CLIENT_ID'],
  client_secret: ENV['SCHWAB_CLIENT_SECRET'],
  redirect_uri: ENV['SCHWAB_REDIRECT_URI']
)
# Returns: { access_token: "...", refresh_token: "...", expires_in: 1800, expires_at: Time }

# Client initialization - Simple (user manages tokens)
client = Schwab::Client.new(access_token: my_stored_token)

# Client initialization - With auto-refresh (user still stores tokens)
client = Schwab::Client.new(
  access_token: my_stored_token,
  refresh_token: my_stored_refresh_token,
  auto_refresh: true,
  on_token_refresh: ->(token_data) { 
    # User decides how to store the new tokens
    MyTokenStore.save(token_data)
  }
)

# Manual token refresh
new_tokens = Schwab::OAuth.refresh_token(
  refresh_token: my_refresh_token,
  client_id: ENV['SCHWAB_CLIENT_ID'],
  client_secret: ENV['SCHWAB_CLIENT_SECRET']
)

# Market data examples (direct methods like Stripe)
quote = client.get_quote('AAPL')
quotes = client.get_quotes(['AAPL', 'GOOGL', 'MSFT'])
history = client.get_price_history('AAPL', 
  period_type: 'day',
  period: 10,
  frequency_type: 'minute',
  frequency: 5
)
option_chain = client.get_option_chain('AAPL',
  contract_type: 'CALL',
  strike_count: 10
)
market_hours = client.get_market_hours('EQUITY', date: Date.today)

# Trading examples
order = client.place_order(
  account_id: '12345',
  symbol: 'AAPL',
  quantity: 100,
  order_type: 'LIMIT',
  price: 150.00,
  instruction: 'BUY',
  duration: 'DAY'
)
client.cancel_order(account_id: '12345', order_id: order.id)
client.replace_order(account_id: '12345', order_id: order.id, 
  price: 149.50
)
orders = client.get_orders(account_id: '12345')
order_status = client.get_order(account_id: '12345', order_id: order.id)

# Account examples
accounts = client.get_accounts
account = client.get_account('12345')
positions = client.get_positions('12345')
transactions = client.get_transactions('12345', 
  start_date: 30.days.ago,
  end_date: Date.today
)
balances = client.get_balances('12345')

# Watchlist examples  
watchlists = client.get_watchlists
watchlist = client.create_watchlist(name: 'Tech Stocks', symbols: ['AAPL', 'GOOGL'])
client.add_to_watchlist(watchlist_id: '123', symbols: ['MSFT'])
client.remove_from_watchlist(watchlist_id: '123', symbols: ['AAPL'])
```

### Error Handling Examples
```ruby
begin
  quote = client.get_quote('AAPL')
rescue Schwab::TokenExpiredError => e
  # Handle expired token
  if client.auto_refresh?
    # Auto-refresh will handle it, retry
    retry
  else
    # Manual refresh needed
    new_tokens = Schwab::OAuth.refresh_token(refresh_token: my_refresh_token)
    MyTokenStore.save(new_tokens)
    client = Schwab::Client.new(access_token: new_tokens[:access_token])
    retry
  end
rescue Schwab::RateLimitError => e
  # Automatic retry with backoff, or handle manually
  sleep(e.retry_after)
  retry
rescue Schwab::ApiError => e
  # Handle other API errors
  puts "Error: #{e.message}"
  puts "Status: #{e.status}"
  puts "Response: #{e.response_body}"
end
```

## Technical Considerations

### Dependencies
- **faraday** (~> 2.0): HTTP client framework
- **oauth2** (~> 2.0): OAuth 2.0 client implementation
- **multi_json** (~> 1.15): Flexible JSON parsing
- **sawyer** (~> 0.9): REST API client framework (builds on Faraday)

### Ruby Version Support
- Minimum Ruby version: 3.1.0
- Tested against Ruby 3.1, 3.2, 3.3

### Thread Safety
- All public methods must be thread-safe
- Token refresh must use mutex to prevent race conditions
- Connection pooling for HTTP clients

### Performance Targets
- Token refresh: < 100ms overhead
- Request preparation: < 10ms
- Support for 100+ concurrent requests

## Success Metrics
1. **Adoption**: 500+ downloads within first 3 months
2. **Reliability**: 99.9% success rate for API calls (excluding Schwab API downtime)
3. **Performance**: Average response time < 200ms for cached token requests
4. **Developer Experience**: 90% of developers can authenticate and make first API call within 15 minutes
5. **Test Coverage**: Maintain > 95% test coverage
6. **Documentation**: 100% of public methods documented with examples
7. **Community**: 10+ community contributors within first year

## Open Questions
1. Should we support PKCE flow in the initial release or add it in v2?
2. Should we provide ActiveRecord/ActiveModel integration helpers?
3. Should we support multiple OAuth apps (different client IDs) in a single client instance?
4. What level of response caching should be built-in vs left to users?
5. Should we provide built-in webhook/callback handling for order status updates?

## Technical Notes

### API Versioning Strategy
The gem will use a configurable base URL to support future API versions:
- Default: `https://api.schwabapi.com`
- Can be overridden in configuration for API version changes
- Version-specific endpoints handled via path construction

### Production Environment
- No sandbox environment available from Schwab
- Recommend using a test account for development
- VCR cassettes strongly recommended for testing to avoid hitting production API
- Consider implementing a "dry run" mode that logs but doesn't execute trades

## Implementation Phases (Dependency-Driven)

### Phase 1: Authentication Foundation (Week 1-2)
**Goal**: Make first successful API call
1. OAuth helper methods (authorization_url, get_token, refresh_token)
2. Basic Client class with access token support
3. HTTP/Faraday setup with token injection
4. Error hierarchy (focus on auth errors first)
5. Minimal configuration (client_id, secret, redirect_uri)
6. First API method: `get_quote` (no dependencies, good test)
7. Basic test suite with VCR

**Deliverable**: Can authenticate and fetch a stock quote

### Phase 2: Account Foundation (Week 3-4)
**Goal**: Access account-specific data
1. Response objects (Sawyer::Resource) for better ergonomics
2. Account methods: get_accounts, get_account
3. Expand error handling for API-specific errors
4. Auto-refresh token support with callback
5. Position and balance methods (need account IDs)
6. Transaction history
7. Comprehensive test coverage

**Deliverable**: Can list accounts and view positions/balances

### Phase 3: Trading Core (Week 5-6)
**Goal**: Place and manage orders
1. Order placement (market, limit orders)
2. Order retrieval and status checking
3. Order cancellation and replacement
4. Additional market data methods (price history, quotes batch)
5. Rate limit handling with retry logic
6. Configuration improvements (sandbox mode, logging)

**Deliverable**: Can execute trades and manage orders

### Phase 4: Enhanced Features (Week 7-8)
**Goal**: Production-ready gem
1. Option chains support
2. Watchlist management  
3. Market hours endpoint
4. Advanced order types (stop-loss, trailing stop)
5. Pagination helpers for large result sets
6. Performance optimizations
7. Documentation and examples
8. Gem release preparation

**Deliverable**: Full-featured v0.1.0 ready for RubyGems