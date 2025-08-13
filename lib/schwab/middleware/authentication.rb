# frozen_string_literal: true

require "faraday"

module Schwab
  module Middleware
    # Faraday middleware for automatic token refresh
    class TokenRefresh < Faraday::Middleware
      def initialize(app, options = {})
        super(app)
        @access_token = options[:access_token]
        @refresh_token = options[:refresh_token]
        @client_id = options[:client_id]
        @client_secret = options[:client_secret]
        @on_token_refresh = options[:on_token_refresh]
        @mutex = Mutex.new
      end

      def call(env)
        # Add the current access token to the request
        env[:request_headers]["Authorization"] = "Bearer #{@access_token}"

        # Make the request
        response = @app.call(env)

        # Check if token expired (401 Unauthorized)
        if response.status == 401 && @refresh_token
          # Thread-safe token refresh
          @mutex.synchronize do
            # Double-check in case another thread already refreshed
            if response.status == 401
              refresh_access_token!

              # Retry the request with new token
              env[:request_headers]["Authorization"] = "Bearer #{@access_token}"
              response = @app.call(env)
            end
          end
        end

        response
      rescue Faraday::UnauthorizedError => e
        # If we get an unauthorized error and have a refresh token, try refreshing
        if @refresh_token
          @mutex.synchronize do
            refresh_access_token!

            # Retry the request with new token
            env[:request_headers]["Authorization"] = "Bearer #{@access_token}"
            @app.call(env)
          end
        else
          raise e
        end
      end

      private

      def refresh_access_token!
        # Use the OAuth module to refresh the token
        result = Schwab::OAuth.refresh_token(
          refresh_token: @refresh_token,
          client_id: @client_id,
          client_secret: @client_secret,
        )

        # Update our tokens
        @access_token = result[:access_token]
        @refresh_token = result[:refresh_token] if result[:refresh_token]

        # Call the callback if provided
        @on_token_refresh&.call(result)

        result
      rescue => e
        # If refresh fails, wrap the error with more context
        raise Schwab::TokenExpiredError, "Failed to refresh access token: #{e.message}"
      end
    end

    # Simple middleware for adding bearer token to requests
    class Authentication < Faraday::Middleware
      def initialize(app, token)
        super(app)
        @token = token
      end

      def call(env)
        env[:request_headers]["Authorization"] = "Bearer #{@token}" if @token
        @app.call(env)
      end
    end
  end
end
