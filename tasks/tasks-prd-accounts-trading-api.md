# Tasks for Accounts & Trading API Methods

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

## Tasks

- [ ] 1. Create Account Management Module and Methods
  - [ ] 1.1 Create `lib/schwab/accounts.rb` module following pattern from `market_data.rb`
  - [ ] 1.2 Implement `get_accounts(fields: nil, client: nil)` method with proper API endpoint mapping
  - [ ] 1.3 Implement `get_account(account_id, fields: nil, client: nil)` for single account retrieval
  - [ ] 1.4 Implement `get_positions(account_id, client: nil)` to fetch account positions
  - [ ] 1.5 Implement `get_account_balances(account_id, client: nil)` for detailed balance info
  - [ ] 1.6 Implement `get_transactions(account_id, from_date:, to_date:, types: nil, client: nil)` with pagination support
  - [ ] 1.7 Implement `get_account_preferences(account_id, client: nil)` for account settings
  - [ ] 1.8 Add module-level methods to `lib/schwab.rb` for accounts functionality
  - [ ] 1.9 Write comprehensive tests in `spec/schwab/accounts_spec.rb` with VCR cassettes
  - [ ] 1.10 Add YARD documentation for all public account methods

- [ ] 2. Create Trading Operations Module and Methods
  - [ ] 2.1 Create `lib/schwab/trading.rb` module with order management methods
  - [ ] 2.2 Implement `place_order(account_id, order:, client: nil)` with order submission logic
  - [ ] 2.3 Implement `cancel_order(account_id, order_id, client: nil)` for order cancellation
  - [ ] 2.4 Implement `replace_order(account_id, order_id, order:, client: nil)` for order modification
  - [ ] 2.5 Implement `get_order(account_id, order_id, client: nil)` for single order status
  - [ ] 2.6 Implement `get_orders(account_id, status: nil, from_date: nil, to_date: nil, client: nil)` with filtering
  - [ ] 2.7 Implement `get_order_history(account_id, from_date:, to_date:, client: nil)` with pagination
  - [ ] 2.8 Add support for all order types (market, limit, stop, stop-limit, trailing stop)
  - [ ] 2.9 Implement complex order support (brackets, OCO, conditional)
  - [ ] 2.10 Add module-level methods to `lib/schwab.rb` for trading functionality
  - [ ] 2.11 Write comprehensive tests in `spec/schwab/trading_spec.rb` with stubbed responses
  - [ ] 2.12 Add YARD documentation for all trading methods

- [ ] 3. Build Options Strategy Builder
  - [ ] 3.1 Create `lib/schwab/options_strategy.rb` with base strategy class
  - [ ] 3.2 Implement `vertical_spread` class method for bull/bear call/put spreads
  - [ ] 3.3 Implement `iron_condor` class method with four-leg validation
  - [ ] 3.4 Implement `butterfly` class method for three-strike strategies
  - [ ] 3.5 Implement `calendar_spread` class method for time spreads
  - [ ] 3.6 Implement `straddle` and `strangle` class methods
  - [ ] 3.7 Implement `iron_butterfly` class method
  - [ ] 3.8 Implement `diagonal_spread` class method
  - [ ] 3.9 Implement `collar` class method for protective strategies
  - [ ] 3.10 Implement `custom` builder with `add_leg` chaining method
  - [ ] 3.11 Add `as_single_order` method for order configuration (price type, limit)
  - [ ] 3.12 Implement strategy validation for strike relationships and expirations
  - [ ] 3.13 Create `lib/schwab/resources/strategy.rb` for strategy object representation
  - [ ] 3.14 Write tests in `spec/schwab/options_strategy_spec.rb` for all strategies
  - [ ] 3.15 Add YARD documentation with examples for each strategy type

- [ ] 4. Implement Resource Object Wrappers
  - [ ] 4.1 Create `lib/schwab/resources/base.rb` with Sawyer::Resource-like functionality
  - [ ] 4.2 Implement method_missing for hash-like access and method calls
  - [ ] 4.3 Create `lib/schwab/resources/account.rb` with account-specific methods
  - [ ] 4.4 Create `lib/schwab/resources/order.rb` with order status helpers
  - [ ] 4.5 Create `lib/schwab/resources/position.rb` with position calculations
  - [ ] 4.6 Create `lib/schwab/resources/transaction.rb` with transaction type helpers
  - [ ] 4.7 Add lazy loading for nested resources
  - [ ] 4.8 Implement type coercion for dates, times, and numeric values
  - [ ] 4.9 Update `lib/schwab/configuration.rb` to add `response_format` option (:hash or :resource)
  - [ ] 4.10 Update response handling in client to use configured format
  - [ ] 4.11 Write tests for each resource class in `spec/schwab/resources/`
  - [ ] 4.12 Document resource object usage patterns

- [ ] 5. Add Order Validation and Preview Features
  - [ ] 5.1 Create `lib/schwab/order_validator.rb` with validation logic
  - [ ] 5.2 Implement symbol validation against known symbols
  - [ ] 5.3 Implement quantity validation (positive integers, lot sizes)
  - [ ] 5.4 Implement price validation for limit/stop orders
  - [ ] 5.5 Implement order type validation (required fields per type)
  - [ ] 5.6 Create `lib/schwab/order_preview.rb` for preview functionality
  - [ ] 5.7 Implement `preview_order(account_id, order:, client: nil)` method
  - [ ] 5.8 Calculate estimated costs, commissions, and fees
  - [ ] 5.9 Calculate margin requirements and buying power effect
  - [ ] 5.10 Add preview support to strategy builder
  - [ ] 5.11 Integrate validation into `place_order` with optional bypass
  - [ ] 5.12 Write comprehensive validation tests in `spec/schwab/order_validator_spec.rb`
  - [ ] 5.13 Write preview tests in `spec/schwab/order_preview_spec.rb`
  - [ ] 5.14 Document validation rules and preview response format