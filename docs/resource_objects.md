# Resource Objects Usage Guide

## Overview

The Schwab Ruby SDK provides two response formats for API data:
- **Hash mode** (default): Returns plain Ruby hashes
- **Resource mode**: Returns rich objects with helper methods

## Configuration

### Setting Response Format

```ruby
# Global configuration
Schwab.configure do |config|
  config.response_format = :resource  # or :hash (default)
end

# Per-client configuration
client = Schwab::Client.new(
  access_token: token,
  config: Schwab::Configuration.new.tap do |c|
    c.response_format = :resource
  end
)
```

## Working with Resource Objects

### Basic Access Patterns

Resource objects provide multiple ways to access data:

```ruby
# Assuming response_format = :resource
account = client.get_account("123456")

# Method access (preferred)
account.account_number        # "123456"
account.total_value           # 50000.00

# Hash-style access (still works)
account[:accountNumber]        # "123456"
account["accountNumber"]       # "123456"

# Checking for keys
account.key?(:status)          # true
account.has_key?("status")     # true

# Getting all keys
account.keys                   # [:accountNumber, :status, ...]

# Converting back to hash
account.to_h                   # { accountNumber: "123456", ... }
```

### Nested Resources

Nested hashes are automatically wrapped in resource objects:

```ruby
account = client.get_account("123456")

# Nested objects are also resources
balances = account.current_balances
balances.cash_balance          # 10000.00
balances.buying_power          # 20000.00

# Deep nesting works automatically
position = account.positions.first
position.instrument.symbol     # "AAPL"
```

### Type Coercion

Resource objects automatically coerce types for known fields:

```ruby
# Dates and times are parsed
account.created_time           # Returns Time/DateTime object
account.opened_date            # Returns Date object

# Booleans are coerced
account.day_trader              # true (from "true" string)
account.pdt_flag                # false (from 0)

# Numbers are coerced
position.quantity               # 100.0 (Float)
account.round_trips             # 3 (Integer)
```

## Resource-Specific Features

### Account Resources

```ruby
account = client.get_account("123456")

# Account type checks
account.margin_account?         # true/false
account.cash_account?           # true/false

# Status checks
account.active?                 # true if status == "ACTIVE"

# Balance shortcuts
account.total_value             # Net liquidation value
account.cash_balance            # Available cash
account.buying_power            # Buying power
account.day_trading_buying_power # Day trading BP

# Margin account features
account.margin_balance          # Margin balance (nil for cash accounts)
account.margin_call?            # true/false/nil

# Position management
account.positions               # Array of Position resources
account.equity_positions        # Only equity positions
account.option_positions        # Only option positions
account.has_positions?          # true/false
account.position_count          # Number of positions

# P&L calculations
account.total_pnl               # Total unrealized P&L
account.todays_pnl              # Today's P&L
account.total_market_value      # Sum of all position values
```

### Position Resources

```ruby
position = account.positions.first

# Basic information
position.symbol                 # "AAPL"
position.quantity               # 100.0
position.average_price          # 150.00 (cost basis per share)
position.current_price          # 155.00

# Calculations
position.market_value           # 15500.00
position.cost_basis             # 15000.00
position.unrealized_pnl         # 500.00
position.unrealized_pnl_percentage # 3.33
position.day_pnl                # 100.00

# Position type checks
position.long?                  # true if quantity > 0
position.short?                 # true if quantity < 0
position.equity?                # true if equity position
position.option?                # true if option position
position.profitable?            # true if unrealized_pnl > 0

# Option-specific features
position.option_details         # Hash with strike, expiration, etc.
position.underlying_symbol      # "AAPL" (for options)
position.strike_price           # 150.00
position.expiration_date        # "2024-03-15"
position.call?                  # true if call option
position.put?                   # true if put option
```

### Order Resources

```ruby
order = client.get_order("order123")

# Order identification
order.order_id                  # "order123"
order.account_id                # "123456"
order.symbol                    # "AAPL" (for single-leg orders)

# Order details
order.status                    # "FILLED", "WORKING", etc.
order.order_type                # "MARKET", "LIMIT", etc.
order.instruction               # "BUY", "SELL", etc.
order.quantity                  # 100.0
order.price                     # 150.00 (for limit orders)

# Status checks
order.pending?                  # true if pending
order.active?                   # true if working/active
order.filled?                   # true if completely filled
order.partially_filled?         # true if partially filled
order.cancelled?                # true if cancelled
order.rejected?                 # true if rejected
order.complete?                 # true if terminal state

# Order type checks
order.market_order?             # true if market order
order.limit_order?              # true if limit order
order.stop_order?               # true if stop order
order.day_order?                # true if DAY duration
order.gtc?                      # true if GTC

# Instruction checks
order.buy?                      # true if buy order
order.sell?                     # true if sell order
order.opening?                  # true if opening position
order.closing?                  # true if closing position

# Complex orders
order.complex?                  # true if multi-leg
order.single_leg?               # true if single-leg
order.option_order?             # true if options order
order.equity_order?             # true if equity order

# Fill information
order.filled_quantity           # 50.0
order.remaining_quantity        # 50.0
order.fill_percentage           # 50.0 (%)
```

### Transaction Resources

```ruby
transaction = client.get_transaction("trans123")

# Transaction identification
transaction.transaction_id      # "trans123"
transaction.transaction_type    # "TRADE", "DIVIDEND", etc.
transaction.date                # Time/Date object

# Transaction details
transaction.symbol              # "AAPL"
transaction.quantity            # 100.0
transaction.price               # 150.00
transaction.net_amount          # 15000.00
transaction.fees                # 0.65
transaction.commission          # 0.00

# Transaction type checks
transaction.trade?              # true if trade
transaction.buy?                # true if buy
transaction.sell?               # true if sell
transaction.dividend?           # true if dividend
transaction.interest?           # true if interest
transaction.deposit?            # true if deposit
transaction.withdrawal?         # true if withdrawal
transaction.option?             # true if option transaction

# Status checks
transaction.pending?            # true if pending
transaction.completed?          # true if completed
transaction.cancelled?          # true if cancelled
```

### Strategy Resources (Options Strategies)

```ruby
strategy = client.get_strategy("strat123")

# Strategy identification
strategy.strategy_type          # "VERTICAL", "IRON_CONDOR", etc.
strategy.underlying_symbol      # "SPY"
strategy.legs                   # Array of strategy legs

# Strategy analysis
strategy.strike_prices          # [420, 425] (all strikes)
strategy.expiration_dates       # ["2024-03-15"] (all expirations)
strategy.net_premium            # -250.00 (debit) or 150.00 (credit)

# Strategy type identification
strategy.vertical_spread?       # true if vertical
strategy.calendar_spread?       # true if calendar
strategy.iron_condor?           # true if iron condor
strategy.iron_butterfly?        # true if iron butterfly
strategy.straddle?              # true if straddle
strategy.strangle?              # true if strangle

# Credit/Debit checks
strategy.credit_strategy?       # true if net credit
strategy.debit_strategy?        # true if net debit

# Display
strategy.to_display_string      # "Iron Condor - SPY - Strikes: 420/425/435/440"
```

## Iteration and Enumeration

Resource objects support enumeration methods:

```ruby
account = client.get_account("123456")

# Iterate over data
account.each do |key, value|
  puts "#{key}: #{value}"
end

# Check if empty
account.empty?                  # false

# Array-like operations on collections
positions = account.positions
positions.map(&:symbol)         # ["AAPL", "GOOGL", "MSFT"]
positions.select(&:profitable?) # Only profitable positions
positions.sum(&:market_value)   # Total market value
```

## Type Safety and Nil Handling

Resource objects handle nil values gracefully:

```ruby
account = client.get_account("123456")

# Safe navigation
account.current_balances&.cash_balance  # Returns nil if no balances

# Type coercion preserves nil
account.closed_date             # nil (if not closed)

# Helper methods return appropriate defaults
empty_account = Schwab::Resources::Account.new({})
empty_account.has_positions?    # false (not nil)
empty_account.position_count    # 0 (not nil)
empty_account.total_pnl         # 0.0 (not nil)
```

## Converting Between Formats

### Resource to Hash

```ruby
# Get resource object
account = client.get_account("123456")  # Resource object

# Convert to hash when needed
hash = account.to_h
JSON.generate(hash)              # For JSON serialization
Redis.set("account", hash)       # For caching
```

### Working with Both Formats

```ruby
# You can always use hash access on resources
account = client.get_account("123456")  # Resource object
account[:accountNumber]          # Works!
account.account_number           # Also works!

# Equality works with hashes
account == account.to_h          # true
```

## Performance Considerations

### When to Use Hash Mode

- High-volume data processing
- Simple data pass-through
- Minimal data manipulation
- Memory-constrained environments

```ruby
# For bulk processing, consider hash mode
client = Schwab::Client.new(token, config: { response_format: :hash })
accounts = client.get_all_accounts  # Array of hashes (faster)
```

### When to Use Resource Mode

- Interactive development (REPL)
- Complex business logic
- Rich domain models
- Better code readability

```ruby
# For application logic, resource mode is cleaner
client = Schwab::Client.new(token, config: { response_format: :resource })
account = client.get_account("123456")
if account.margin_call? && account.equity < account.maintenance_requirement
  # Handle margin call
end
```

## Testing with Resources

```ruby
# Create test resources easily
test_account = Schwab::Resources::Account.new(
  accountNumber: "TEST123",
  type: "MARGIN",
  currentBalances: {
    cashBalance: 10000.00,
    buyingPower: 20000.00
  }
)

# Assertions work naturally
expect(test_account.margin_account?).to be true
expect(test_account.cash_balance).to eq(10000.00)

# Mock responses
allow(client).to receive(:get_account).and_return(
  Schwab::Resources::Account.new(mock_data)
)
```

## Common Patterns

### Filtering and Searching

```ruby
# Find all profitable positions
profitable = account.positions.select(&:profitable?)

# Find positions by symbol
aapl_positions = account.positions.select { |p| p.symbol == "AAPL" }

# Sum values
total_equity_value = account.equity_positions.sum(&:market_value)
```

### Conditional Logic

```ruby
# Clean conditional checks
if account.margin_account? && account.margin_call?
  notify_margin_call(account)
end

# Position management
account.positions.each do |position|
  if position.option? && position.expiration_date < Date.today + 7
    puts "Option expiring soon: #{position.symbol}"
  end
end
```

### Data Transformation

```ruby
# Transform to custom format
position_summary = account.positions.map do |pos|
  {
    symbol: pos.symbol,
    value: pos.market_value,
    pnl: pos.unrealized_pnl,
    pnl_percent: pos.unrealized_pnl_percentage
  }
end

# Group by type
positions_by_type = account.positions.group_by(&:asset_type)
```

## Migration Guide

### From Hash to Resource Mode

```ruby
# Before (hash mode)
account = client.get_account("123456")
balance = account[:currentBalances][:cashBalance]
is_active = account[:status] == "ACTIVE"

# After (resource mode)
account = client.get_account("123456")
balance = account.cash_balance        # Cleaner!
is_active = account.active?           # More intuitive!
```

### Gradual Migration

You can migrate gradually by using both access patterns:

```ruby
# During migration, both work
account = client.get_account("123456")  # Resource mode
legacy_code(account.to_h)               # Pass hash to legacy code
new_code(account)                       # Use resource in new code
```