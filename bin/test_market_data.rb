#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "schwab"
require "json"
require "dotenv"
require_relative "shared/token_manager"

Dotenv.load

# Ensure we have fresh tokens
tokens = TokenManager.load_tokens
puts "Using access token: #{tokens[:access_token][0..20]}..."

# Configure the client
client = Schwab::Client.new(
  access_token: tokens[:access_token],
  refresh_token: tokens[:refresh_token],
)

puts "\n📊 Testing Market Data Endpoints"
puts "=" * 50

# Test get_quotes (multiple symbols)
puts "\n1. Testing get_quotes with multiple symbols..."
begin
  result = Schwab::MarketData.get_quotes(["AAPL", "MSFT", "GOOGL"], client: client)
  puts "✅ Success! Got #{result.keys.length} quotes"
  result.keys.each do |symbol|
    quote = result[symbol]
    regular = quote["regular"]
    if regular
      puts "  #{symbol}: $#{regular["regularMarketLastPrice"]} (#{regular["regularMarketPercentChange"]}%)"
    end
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
end

# Test get_quote (single symbol)
puts "\n2. Testing get_quote for single symbol (AAPL)..."
begin
  result = Schwab::MarketData.get_quote("AAPL", client: client)
  puts "✅ Success!"
  # Get_quote returns quotes for the symbol, need to get the first value
  quote_data = result.values.first
  if quote_data
    puts "  Symbol: #{quote_data["symbol"]}"
    puts "  Price: $#{quote_data["quote"]["lastPrice"]}"
    puts "  Volume: #{quote_data["quote"]["totalVolume"]}"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
end

# Test get_quote_history
puts "\n3. Testing get_quote_history for AAPL (last 5 days)..."
begin
  result = Schwab::MarketData.get_quote_history(
    "AAPL",
    period_type: "day",
    period: 5,
    frequency_type: "minute",
    frequency: 30,
    client: client,
  )
  puts "✅ Success!"
  if result["candles"]
    puts "  Got #{result["candles"].length} candles"
    if result["candles"].any?
      last_candle = result["candles"].last
      puts "  Last candle: Open=$#{last_candle["open"]}, Close=$#{last_candle["close"]}"
    end
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
end

# Test get_movers
puts "\n4. Testing get_movers for $SPX..."
begin
  result = Schwab::MarketData.get_movers("$SPX", direction: "up", change: "percent", client: client)
  screeners = result["screeners"] || []
  puts "✅ Success! Got #{screeners.length} movers"
  if screeners.any?
    top_mover = screeners.first
    puts "  Top mover: #{top_mover["symbol"]} - #{top_mover["description"]} (#{top_mover["netPercentChange"]}%)"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
end

# Test get_market_hours
puts "\n5. Testing get_market_hours for EQUITY..."
begin
  result = Schwab::MarketData.get_market_hours("EQUITY", client: client)
  puts "✅ Success!"
  if result["equity"]
    market = result["equity"]["EQ"]
    puts "  Market is #{market["isOpen"] ? "OPEN" : "CLOSED"}"
    if market["sessionHours"] && market["sessionHours"]["regularMarket"]
      regular = market["sessionHours"]["regularMarket"].first
      if regular
        puts "  Regular hours: #{regular["start"]} - #{regular["end"]}"
      end
    end
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
end

# Test get_market_hour (single market)
puts "\n6. Testing get_market_hour for EQUITY..."
begin
  result = Schwab::MarketData.get_market_hour("EQUITY", client: client)
  puts "✅ Success!"
  if result["equity"]
    market = result["equity"]["EQ"]
    puts "  Market is #{market["isOpen"] ? "OPEN" : "CLOSED"}"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n" + "=" * 50
puts "Testing complete!"
