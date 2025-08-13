# frozen_string_literal: true

require "faraday"
require "faraday/middleware"

module Schwab
  # HTTP connection builder for Schwab API
  module Connection
    # Build a Faraday connection with the configured middleware stack
    #
    # @param access_token [String, nil] OAuth access token for authentication
    # @param config [Configuration] Configuration object with connection settings
    # @return [Faraday::Connection] Configured Faraday connection
    def self.build(access_token: nil, config: nil)
      config ||= Schwab.configuration || Configuration.new

      Faraday.new(url: config.api_endpoint) do |conn|
        # Request middleware (executed in order)
        conn.request(:json) # Encode request bodies as JSON
        conn.request(:authorization, "Bearer", access_token) if access_token

        # Response middleware (executed in reverse order)
        conn.response(:json, content_type: /\bjson$/) # Parse JSON responses
        conn.response(:raise_error) # Raise exceptions for 4xx/5xx responses
        conn.response(:logger, config.logger, { headers: false, bodies: false }) if config.logger

        # Adapter (must be last)
        conn.adapter(config.faraday_adapter)

        # Connection options
        conn.options.timeout = config.timeout
        conn.options.open_timeout = config.open_timeout
      end
    end

    # Build a connection with automatic token refresh capability
    #
    # @param access_token [String] Initial access token
    # @param refresh_token [String, nil] Refresh token for automatic refresh
    # @param on_token_refresh [Proc, nil] Callback when token is refreshed
    # @param config [Configuration] Configuration object
    # @return [Faraday::Connection] Configured connection with refresh capability
    def self.build_with_refresh(access_token:, refresh_token: nil, on_token_refresh: nil, config: nil)
      config ||= Schwab.configuration || Configuration.new

      Faraday.new(url: config.api_endpoint) do |conn|
        # Request middleware
        conn.request(:json)

        # Custom middleware for token refresh will be added here
        if refresh_token
          conn.use(
            Middleware::TokenRefresh,
            access_token: access_token,
            refresh_token: refresh_token,
            client_id: config.client_id,
            client_secret: config.client_secret,
            on_token_refresh: on_token_refresh,
          )
        else
          conn.request(:authorization, "Bearer", access_token)
        end

        # Response middleware
        conn.response(:json, content_type: /\bjson$/)
        conn.response(:raise_error)
        conn.response(:logger, config.logger, { headers: false, bodies: false }) if config.logger

        # Adapter
        conn.adapter(config.faraday_adapter)

        # Connection options
        conn.options.timeout = config.timeout
        conn.options.open_timeout = config.open_timeout
      end
    end
  end
end
