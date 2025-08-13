#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to manually record VCR cassettes with real credentials

require "bundler/setup"
require_relative "../lib/schwab"
require_relative "support/vcr"
require "json"
require "dotenv"
require_relative "../bin/shared/token_manager"

Dotenv.load

# Ensure we have fresh tokens
tokens = TokenManager.load_tokens
puts "Using refresh token: #{tokens[:refresh_token][0..20]}..."

# Record VCR cassette for refresh_token
VCR.use_cassette("oauth_refresh_token_success") do
  puts "\n📼 Recording VCR cassette for OAuth.refresh_token..."

  result = Schwab::OAuth.refresh_token(
    refresh_token: tokens[:refresh_token],
    client_id: ENV["SCHWAB_CLIENT_ID"],
    client_secret: ENV["SCHWAB_CLIENT_SECRET"],
  )

  puts "✅ Success! Recorded response:"
  puts "  - Access token: #{result[:access_token][0..20]}..."
  puts "  - Refresh token: #{result[:refresh_token][0..20]}..." if result[:refresh_token]
  puts "  - Expires in: #{result[:expires_in]}"

  # Save new tokens
  File.write(TokenManager::TOKENS_FILE, JSON.pretty_generate(result))
  puts "\n💾 Updated tokens saved"
end

puts "\n📼 VCR cassette saved to: spec/fixtures/vcr_cassettes/oauth_refresh_token_success.yml"
