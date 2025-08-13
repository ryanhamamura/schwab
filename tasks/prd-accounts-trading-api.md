# PRD: Accounts & Trading API Methods

## Introduction/Overview

This feature extends the Schwab Ruby SDK to include comprehensive account management and trading functionality. Building upon the existing OAuth authentication and market data foundation, this enhancement enables developers to retrieve account information, manage positions, and execute trades programmatically through the Schwab API.

The implementation will follow Ruby idioms by using a hybrid approach: returning raw hashes by default for simplicity, with optional object wrappers (similar to Octokit's Sawyer::Resource pattern) for enhanced functionality and type safety.

## Goals

1. Provide complete coverage of Schwab's account and trading API endpoints
2. Enable developers to retrieve account balances, positions, and transaction history
3. Support all standard order types (market, limit, stop, stop-limit, trailing stop)
4. Implement robust error handling with detailed messages and automatic retry logic
5. Ensure order validation before submission to prevent API errors
6. Maintain consistency with existing SDK patterns and Ruby best practices
7. Achieve 80%+ test coverage for all new functionality

## User Stories

1. **As a developer**, I want to retrieve all accounts associated with my credentials so that I can manage multiple accounts programmatically.

2. **As a developer**, I want to get real-time account balances and positions so that I can make informed trading decisions.

3. **As a developer**, I want to place various types of orders (market, limit, stop) so that I can execute different trading strategies.

4. **As a developer**, I want to cancel or modify existing orders so that I can react to market changes.

5. **As a developer**, I want to retrieve transaction history so that I can track account activity and performance.

6. **As a developer**, I want clear error messages when orders fail so that I can debug issues quickly.

7. **As a developer**, I want automatic retry logic for transient failures so that my application is more resilient.

## Functional Requirements

### Account Operations

1. **Get Single Account** - Retrieve detailed information for a specific account
   - Input: account_id
   - Output: Account details including type, status, balances

2. **Get All Accounts** - List all accounts accessible with current credentials
   - Input: optional fields parameter for filtering response
   - Output: Array of account summaries

3. **Get Account Positions** - Retrieve current positions for an account
   - Input: account_id
   - Output: Array of position details with current values

4. **Get Account Balances** - Get detailed balance information
   - Input: account_id
   - Output: Cash balances, buying power, margin details

5. **Get Transaction History** - Retrieve historical transactions
   - Input: account_id, date range, transaction type filters
   - Output: Paginated transaction list

6. **Get Account Preferences** - Retrieve account settings and preferences
   - Input: account_id
   - Output: Account preferences and configuration

### Trading Operations

7. **Place Order** - Submit a new order to the market
   - Input: account_id, order object with type, symbol, quantity, etc.
   - Output: Order confirmation with order_id

8. **Cancel Order** - Cancel a pending order
   - Input: account_id, order_id
   - Output: Cancellation confirmation

9. **Replace Order** - Modify an existing order
   - Input: account_id, order_id, new order parameters
   - Output: Updated order details

10. **Get Order Status** - Check status of a specific order
    - Input: account_id, order_id
    - Output: Current order status and details

11. **Get All Orders** - Retrieve all orders for an account
    - Input: account_id, optional filters (status, date range)
    - Output: Array of orders

12. **Get Order History** - Retrieve historical orders
    - Input: account_id, date range
    - Output: Paginated historical order list

### Order Types Support

13. **Market Orders** - Buy/sell at current market price
14. **Limit Orders** - Buy/sell at specified price or better
15. **Stop Orders** - Trigger market order when price reaches threshold
16. **Stop-Limit Orders** - Trigger limit order when price reaches threshold
17. **Trailing Stop Orders** - Dynamic stop that follows price movement
18. **Complex Orders** - Support for brackets, OCO, and conditional orders

### Response Format

19. **Hash Responses** - Default response format as Ruby hashes for simplicity
20. **Object Wrappers** - Optional Schwab::Resource objects (like Sawyer::Resource)
    - Accessible as both hash keys and methods
    - Lazy loading for nested resources
    - Type coercion for dates/times

### Error Handling

21. **Detailed Error Messages** - Include API error codes, messages, and field-level errors
22. **Automatic Retry Logic** - Configurable retry for 429 (rate limit) and 503 (service unavailable)
23. **Order Validation** - Client-side validation before API submission
    - Symbol validation
    - Quantity and price checks
    - Order type requirements

### Data Management

24. **Optional Caching** - Cache account data with configurable TTL (default: 30 seconds)
    - Cache keys: account_id + data_type
    - Manual cache invalidation available
    - Bypass cache with `fresh: true` parameter

## Non-Goals (Out of Scope)

1. Paper trading/simulation mode - Users should implement their own simulation layer
2. Position size limits or daily trading limits - Leave risk management to users
3. Order confirmation dialogs - This is a programmatic API, not a UI
4. Real-time WebSocket streaming - Will be addressed in separate WebSocket feature
5. Advanced analytics or reporting - Focus on core API functionality
6. Tax calculation or reporting features

## Design Considerations

### Module Structure
```ruby
# New modules to add
lib/schwab/
  accounts.rb         # Account-related methods
  trading.rb          # Trading/order methods  
  resources/          # Optional object wrappers
    base.rb          # Base resource class
    account.rb       # Account resource
    order.rb         # Order resource
    position.rb      # Position resource
    transaction.rb   # Transaction resource
```

### Method Signatures
```ruby
# Account methods
get_accounts(fields: nil, client: nil)
get_account(account_id, fields: nil, client: nil)
get_positions(account_id, client: nil)
get_transactions(account_id, from_date:, to_date:, types: nil, client: nil)

# Trading methods
place_order(account_id, order:, client: nil)
cancel_order(account_id, order_id, client: nil)
replace_order(account_id, order_id, order:, client: nil)
get_orders(account_id, status: nil, from_date: nil, to_date: nil, client: nil)

# Response format options
Schwab.configure do |config|
  config.response_format = :hash  # default
  # or
  config.response_format = :resource  # for object wrappers
end
```

## Technical Considerations

1. **Authentication** - Use existing OAuth setup with appropriate scopes
2. **Rate Limiting** - Leverage existing rate limit middleware (120 req/min)
3. **API Versioning** - Target Schwab API v1
4. **Dependencies** - No new gems required, use existing Faraday setup
5. **Thread Safety** - Ensure all methods are thread-safe for concurrent usage
6. **Memory Management** - Stream large result sets to avoid memory issues

## Success Metrics

1. All account and trading endpoints implemented and tested
2. Test coverage ≥ 80% for new code
3. Average response time < 500ms for account queries
4. Successful order placement rate > 99% (excluding validation failures)
5. Zero security vulnerabilities in Brakeman scan
6. Complete YARD documentation for all public methods
7. Successfully handle all documented Schwab API error codes

## Decisions

Based on requirements discussion, the following decisions have been made:

1. **Order Queue System**: No queue implementation - direct API calls. Users will handle their own queuing/throttling needs.

2. **Market Support**: US equities and options only in initial release. International/forex can be added later if needed.

3. **Order Strategy Helpers**: Provide a strategy builder pattern for complex orders, allowing flexible composition of multi-leg strategies.

4. **Order Preview**: Include full preview functionality with estimated costs, commissions, and margin impact before order submission.

5. **Session Management**: Use existing OAuth token refresh mechanism (already implemented). No additional session management needed.

6. **Account Types**: Treat all account types uniformly, returning raw API data. Users can implement account-type-specific logic as needed.

## Additional Requirements Based on Decisions

### Strategy Builder Pattern for Options

The strategy builder should support common multi-leg options strategies with proper validation:

```ruby
# Vertical Spread (Bull Call or Bear Put)
strategy = Schwab::OptionsStrategy.vertical_spread(
  symbol: "AAPL",
  expiration: "2024-03-15",
  buy_strike: 150,
  sell_strike: 155,
  quantity: 10,
  spread_type: :call  # or :put
)

# Iron Condor
strategy = Schwab::OptionsStrategy.iron_condor(
  symbol: "SPY",
  expiration: "2024-03-15",
  put_sell_strike: 420,
  put_buy_strike: 415,
  call_sell_strike: 440,
  call_buy_strike: 445,
  quantity: 5
)

# Butterfly
strategy = Schwab::OptionsStrategy.butterfly(
  symbol: "AAPL",
  expiration: "2024-03-15",
  lower_strike: 145,
  middle_strike: 150,
  upper_strike: 155,
  quantity: 10,
  option_type: :call  # or :put
)

# Calendar Spread
strategy = Schwab::OptionsStrategy.calendar_spread(
  symbol: "AAPL",
  strike: 150,
  near_expiration: "2024-02-15",
  far_expiration: "2024-03-15",
  quantity: 10,
  option_type: :call  # or :put
)

# Straddle
strategy = Schwab::OptionsStrategy.straddle(
  symbol: "AAPL",
  expiration: "2024-03-15",
  strike: 150,
  quantity: 10,
  direction: :long  # or :short
)

# Custom strategy builder for complex combinations
strategy = Schwab::OptionsStrategy.custom
  .add_leg(:buy_to_open, symbol: "AAPL", expiration: "2024-03-15", strike: 150, option_type: :call, quantity: 10)
  .add_leg(:sell_to_open, symbol: "AAPL", expiration: "2024-03-15", strike: 155, option_type: :call, quantity: 10)
  .add_leg(:sell_to_open, symbol: "AAPL", expiration: "2024-03-15", strike: 145, option_type: :put, quantity: 10)
  .add_leg(:buy_to_open, symbol: "AAPL", expiration: "2024-03-15", strike: 140, option_type: :put, quantity: 10)
  .as_single_order(price_type: :net_credit, limit_price: 2.50)

# Submit the strategy
place_order(account_id, strategy: strategy)
```

### Supported Options Strategies

1. **Vertical Spreads** - Bull/Bear Call/Put spreads
2. **Iron Condor** - Four-leg neutral strategy
3. **Iron Butterfly** - Four-leg neutral strategy with strikes converging
4. **Butterfly** - Three-strike strategy (long/short)
5. **Calendar/Horizontal Spreads** - Different expirations, same strike
6. **Diagonal Spreads** - Different expirations and strikes
7. **Straddle** - Same strike calls and puts
8. **Strangle** - Different strike calls and puts
9. **Collar** - Protective put with covered call
10. **Condor** - Four-strike strategy
11. **Ratio Spreads** - Unequal quantities
12. **Custom Combinations** - Build any multi-leg strategy

### Strategy Validation

The builder should validate:
- Proper strike relationships (e.g., bull call spread buy strike < sell strike)
- Expiration dates are valid and in correct order for calendar spreads
- Quantities make sense for the strategy type
- Option chains exist for the requested symbols/expirations

### Order Preview
```ruby
# Preview before submission
preview = preview_order(account_id, order: order_params)
# Returns: estimated_cost, commission, margin_requirement, buying_power_effect
```