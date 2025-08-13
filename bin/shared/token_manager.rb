#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "time"
require "dotenv"

Dotenv.load

module TokenManager
  TOKENS_FILE = ".schwab_tokens.json"

  class << self
    def ensure_fresh_token
      unless File.exist?(TOKENS_FILE)
        puts "No saved tokens found. Run bin/oauth_test.rb first."
        exit(1)
      end

      tokens = JSON.parse(File.read(TOKENS_FILE), symbolize_names: true)
      expires_at = Time.parse(tokens[:expires_at])

      # Check if token expires in less than 5 minutes
      if expires_at < Time.now + 300
        puts "⚠️  Token expires soon (at #{expires_at}). Refreshing..."

        require_relative "../../lib/schwab"

        begin
          result = Schwab::OAuth.refresh_token(
            refresh_token: tokens[:refresh_token],
            client_id: ENV["SCHWAB_CLIENT_ID"],
            client_secret: ENV["SCHWAB_CLIENT_SECRET"],
          )

          puts "✅ Token refreshed successfully!"
          puts "  New access token: #{result[:access_token][0..20]}..."
          puts "  Expires in: #{result[:expires_in]} seconds"

          # Save the new tokens
          File.write(TOKENS_FILE, JSON.pretty_generate(result))
          puts "💾 New tokens saved"

          result
        rescue => e
          puts "❌ Token refresh failed: #{e.message}"
          puts "Please run bin/oauth_test.rb to get new tokens."
          exit(1)
        end
      else
        puts "✅ Token is still valid (expires at #{expires_at})"
        tokens
      end
    end

    def load_tokens
      ensure_fresh_token
    end
  end
end
