# Schwab

Ruby SDK for the Charles Schwab API, providing easy access to trading, market data, and portfolio management endpoints.

## Features

- OAuth 2.0 authentication
- Trading operations (orders, positions)
- Real-time and historical market data
- Account and portfolio management
- Watchlist management
- Options chains and trading

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'schwab'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install schwab
```

## Usage

### Authentication

```ruby
require 'schwab'

client = Schwab::Client.new(
  client_id: 'YOUR_CLIENT_ID',
  client_secret: 'YOUR_CLIENT_SECRET',
  redirect_uri: 'YOUR_REDIRECT_URI'
)

# Get authorization URL
auth_url = client.authorization_url

# After user authorizes, exchange code for token
client.authorize(code: 'AUTHORIZATION_CODE')
```

### Market Data

```ruby
# Get quote for a symbol
quote = client.get_quote('AAPL')

# Get multiple quotes
quotes = client.get_quotes(['AAPL', 'GOOGL', 'MSFT'])

# Get price history
history = client.get_price_history('AAPL', 
  period_type: 'day',
  period: 10,
  frequency_type: 'minute',
  frequency: 5
)
```

### Trading

```ruby
# Get positions
positions = client.get_positions(account_id)

# Place an order
order = client.place_order(account_id, {
  orderType: 'LIMIT',
  symbol: 'AAPL',
  quantity: 100,
  price: 150.00,
  instruction: 'BUY'
})

# Get orders
orders = client.get_orders(account_id)
```

### Account Management

```ruby
# Get accounts
accounts = client.get_accounts

# Get specific account
account = client.get_account(account_id)

# Get transactions
transactions = client.get_transactions(account_id)
```

## Configuration

You can configure the client globally:

```ruby
Schwab.configure do |config|
  config.client_id = 'YOUR_CLIENT_ID'
  config.client_secret = 'YOUR_CLIENT_SECRET'
  config.redirect_uri = 'YOUR_REDIRECT_URI'
  config.sandbox = true # Use sandbox environment
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ryanhamamura/schwab.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer

This gem is not affiliated with, endorsed by, or sponsored by Charles Schwab & Co., Inc. Use at your own risk. Trading securities involves risk, and past performance is not indicative of future results.