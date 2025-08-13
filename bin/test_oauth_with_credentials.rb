#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "schwab"
require "json"
require "dotenv"
require_relative "shared/token_manager"

Dotenv.load

# Load saved tokens (this will auto-refresh if needed)
tokens = TokenManager.load_tokens
puts "Found saved tokens!"
puts "Access token: #{tokens[:access_token][0..20]}..."
puts "Refresh token: #{tokens[:refresh_token][0..20]}..."

# Test refresh token
puts "\n🔄 Testing OAuth.refresh_token..."
begin
  result = Schwab::OAuth.refresh_token(
    refresh_token: tokens[:refresh_token],
    client_id: ENV["SCHWAB_CLIENT_ID"],
    client_secret: ENV["SCHWAB_CLIENT_SECRET"],
  )

  puts "✅ Token refresh successful!"
  puts "New access token: #{result[:access_token][0..20]}..."
  puts "New refresh token: #{result[:refresh_token][0..20]}..." if result[:refresh_token]
  puts "Expires in: #{result[:expires_in]} seconds"

  # Save the new tokens automatically
  puts "\n💾 Saving new tokens..."
  File.write(TokenManager::TOKENS_FILE, JSON.pretty_generate(result))
  puts "Tokens saved!"
rescue => e
  puts "❌ Token refresh failed: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n📝 Note: To test OAuth.get_token, you need a fresh authorization code."
puts "Authorization codes expire within minutes, so we can't test with an old one."
