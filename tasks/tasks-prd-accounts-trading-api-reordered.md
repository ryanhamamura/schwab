# Tasks for Accounts & Trading API Methods (Dependency-Ordered)

## Dependency Analysis

### Existing Components (Already Implemented)
- ✅ `lib/schwab/client.rb` - HTTP client with auth
- ✅ `lib/schwab/connection.rb` - Faraday connection builder
- ✅ `lib/schwab/configuration.rb` - Configuration management
- ✅ `lib/schwab/error.rb` - Error classes
- ✅ `lib/schwab/market_data.rb` - Pattern to follow for modules
- ✅ Authentication middleware with token refresh
- ✅ Rate limiting middleware

### Dependency Chain
1. **Resource Wrappers** → Blocks: All modules (if using resource format)
2. **Configuration Update** → Blocks: Resource wrappers
3. **Account Management** → Blocks: Order preview (needs account data)
4. **Order Validation** → Blocks: Trading operations (validation before submit)
5. **Order Preview** → Blocks: Trading operations (preview before submit)
6. **Trading Operations** → Blocks: Options Strategy Builder
7. **Options Strategy** → Depends on: Trading operations

## Relevant Files

- `lib/schwab/accounts.rb` - New module for account-related API methods
- `lib/schwab/trading.rb` - New module for trading/order API methods
- `lib/schwab/options_strategy.rb` - New module for options strategy builder
- `lib/schwab/resources/base.rb` - Base resource class for object wrappers
- `lib/schwab/resources/account.rb` - Account resource object wrapper
- `lib/schwab/resources/order.rb` - Order resource object wrapper
- `lib/schwab/resources/position.rb` - Position resource object wrapper
- `lib/schwab/resources/transaction.rb` - Transaction resource object wrapper
- `lib/schwab/resources/strategy.rb` - Options strategy resource wrapper
- `lib/schwab/order_validator.rb` - Client-side order validation
- `lib/schwab/order_preview.rb` - Order preview functionality
- `lib/schwab.rb` - Main module (needs updating to include new modules)
- `lib/schwab/configuration.rb` - Configuration (add response_format option)
- `spec/schwab/accounts_spec.rb` - Tests for account methods
- `spec/schwab/trading_spec.rb` - Tests for trading methods
- `spec/schwab/options_strategy_spec.rb` - Tests for options strategy builder
- `spec/schwab/resources/*_spec.rb` - Tests for resource objects

## Notes

- Follow existing patterns from market_data.rb for module structure
- Use existing Client and Connection classes for API communication
- Leverage existing error handling and rate limiting middleware
- Ensure all methods support both module-level and instance-level calls
- Add comprehensive YARD documentation for all public methods
- Write tests alongside implementation for each component
- Use VCR for recording API interactions in tests

## Tasks (Reordered by Dependencies)

- [ ] 1. Update Configuration for Response Format Support
  - [x] 1.1 Update `lib/schwab/configuration.rb` to add `response_format` option (:hash or :resource)
  - [x] 1.2 Add default value `:hash` for backward compatibility
  - [x] 1.3 Add validation for response_format values
  - [x] 1.4 Write tests for configuration changes
  - [x] 1.5 Update configuration documentation

- [ ] 2. Implement Resource Object Wrappers (Foundation)
  - [ ] 2.1 Create `lib/schwab/resources/base.rb` with Sawyer::Resource-like functionality
  - [ ] 2.2 Implement method_missing for hash-like access and method calls
  - [ ] 2.3 Implement type coercion for dates, times, and numeric values
  - [ ] 2.4 Add lazy loading for nested resources
  - [ ] 2.5 Create `lib/schwab/resources/account.rb` with account-specific methods
  - [ ] 2.6 Create `lib/schwab/resources/position.rb` with position calculations
  - [ ] 2.7 Create `lib/schwab/resources/transaction.rb` with transaction type helpers
  - [ ] 2.8 Create `lib/schwab/resources/order.rb` with order status helpers
  - [ ] 2.9 Create `lib/schwab/resources/strategy.rb` for strategy object representation
  - [ ] 2.10 Update response handling in client to use configured format
  - [ ] 2.11 Write tests for each resource class in `spec/schwab/resources/`
  - [ ] 2.12 Document resource object usage patterns

- [ ] 3. Create Account Management Module and Methods
  - [ ] 3.1 Create `lib/schwab/accounts.rb` module following pattern from `market_data.rb`
  - [ ] 3.2 Implement `get_accounts(fields: nil, client: nil)` method with proper API endpoint mapping
  - [ ] 3.3 Implement `get_account(account_id, fields: nil, client: nil)` for single account retrieval
  - [ ] 3.4 Implement `get_positions(account_id, client: nil)` to fetch account positions
  - [ ] 3.5 Implement `get_account_balances(account_id, client: nil)` for detailed balance info
  - [ ] 3.6 Implement `get_transactions(account_id, from_date:, to_date:, types: nil, client: nil)` with pagination support
  - [ ] 3.7 Implement `get_account_preferences(account_id, client: nil)` for account settings
  - [ ] 3.8 Add module-level methods to `lib/schwab.rb` for accounts functionality
  - [ ] 3.9 Write comprehensive tests in `spec/schwab/accounts_spec.rb` with VCR cassettes
  - [ ] 3.10 Add YARD documentation for all public account methods

- [ ] 4. Add Order Validation and Preview Features
  - [ ] 4.1 Create `lib/schwab/order_validator.rb` with validation logic
  - [ ] 4.2 Implement symbol validation against known symbols (use market data API)
  - [ ] 4.3 Implement quantity validation (positive integers, lot sizes)
  - [ ] 4.4 Implement price validation for limit/stop orders
  - [ ] 4.5 Implement order type validation (required fields per type)
  - [ ] 4.6 Create `lib/schwab/order_preview.rb` for preview functionality
  - [ ] 4.7 Implement `preview_order(account_id, order:, client: nil)` method
  - [ ] 4.8 Calculate estimated costs, commissions, and fees
  - [ ] 4.9 Calculate margin requirements and buying power effect (needs account data)
  - [ ] 4.10 Write comprehensive validation tests in `spec/schwab/order_validator_spec.rb`
  - [ ] 4.11 Write preview tests in `spec/schwab/order_preview_spec.rb`
  - [ ] 4.12 Document validation rules and preview response format

- [ ] 5. Create Trading Operations Module and Methods
  - [ ] 5.1 Create `lib/schwab/trading.rb` module with order management methods
  - [ ] 5.2 Implement `place_order(account_id, order:, client: nil)` with order submission logic
  - [ ] 5.3 Integrate validation into `place_order` with optional bypass
  - [ ] 5.4 Implement `cancel_order(account_id, order_id, client: nil)` for order cancellation
  - [ ] 5.5 Implement `replace_order(account_id, order_id, order:, client: nil)` for order modification
  - [ ] 5.6 Implement `get_order(account_id, order_id, client: nil)` for single order status
  - [ ] 5.7 Implement `get_orders(account_id, status: nil, from_date: nil, to_date: nil, client: nil)` with filtering
  - [ ] 5.8 Implement `get_order_history(account_id, from_date:, to_date:, client: nil)` with pagination
  - [ ] 5.9 Add support for all order types (market, limit, stop, stop-limit, trailing stop)
  - [ ] 5.10 Implement complex order support (brackets, OCO, conditional)
  - [ ] 5.11 Add module-level methods to `lib/schwab.rb` for trading functionality
  - [ ] 5.12 Write comprehensive tests in `spec/schwab/trading_spec.rb` with stubbed responses
  - [ ] 5.13 Add YARD documentation for all trading methods

- [ ] 6. Build Options Strategy Builder
  - [ ] 6.1 Create `lib/schwab/options_strategy.rb` with base strategy class
  - [ ] 6.2 Implement `vertical_spread` class method for bull/bear call/put spreads
  - [ ] 6.3 Implement `iron_condor` class method with four-leg validation
  - [ ] 6.4 Implement `butterfly` class method for three-strike strategies
  - [ ] 6.5 Implement `calendar_spread` class method for time spreads
  - [ ] 6.6 Implement `straddle` and `strangle` class methods
  - [ ] 6.7 Implement `iron_butterfly` class method
  - [ ] 6.8 Implement `diagonal_spread` class method
  - [ ] 6.9 Implement `collar` class method for protective strategies
  - [ ] 6.10 Implement `custom` builder with `add_leg` chaining method
  - [ ] 6.11 Add `as_single_order` method for order configuration (price type, limit)
  - [ ] 6.12 Implement strategy validation for strike relationships and expirations
  - [ ] 6.13 Add preview support to strategy builder (uses order_preview.rb)
  - [ ] 6.14 Write tests in `spec/schwab/options_strategy_spec.rb` for all strategies
  - [ ] 6.15 Add YARD documentation with examples for each strategy type

## Implementation Order Summary

1. **Configuration & Infrastructure** (Tasks 1-2): Set up response format support and resource wrappers
2. **Account Management** (Task 3): Implement account methods (no blockers)
3. **Validation & Preview** (Task 4): Build standalone validation/preview (used by trading)
4. **Trading Operations** (Task 5): Core trading functionality (uses validation)
5. **Options Strategies** (Task 6): Advanced features (depends on trading)