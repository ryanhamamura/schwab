#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "schwab"
require "json"
require "dotenv"
require "pp"
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

puts "\n📊 Debug Market Data Responses"
puts "=" * 50

# Test get_quote (single symbol)
puts "\n1. Debug get_quote for AAPL..."
begin
  result = Schwab::MarketData.get_quote("AAPL", client: client)
  puts "Response structure:"
  pp(result)
rescue => e
  puts "❌ Error: #{e.message}"
end

# Test get_movers
puts "\n2. Debug get_movers for $SPX..."
begin
  result = Schwab::MarketData.get_movers("$SPX", direction: "up", change: "percent", client: client)
  puts "Response type: #{result.class}"
  puts "Response structure:"
  pp(result.first(2)) if result.is_a?(Array)
  pp(result) if result.is_a?(Hash)
rescue => e
  puts "❌ Error: #{e.message}"
end

# Test get_market_hours
puts "\n3. Debug get_market_hours for EQUITY..."
begin
  result = Schwab::MarketData.get_market_hours("EQUITY", client: client)
  puts "Response structure:"
  pp(result)
rescue => e
  puts "❌ Error: #{e.message}"
end
