# frozen_string_literal: true

require_relative "connection"
require_relative "middleware/authentication"
require_relative "middleware/rate_limit"

module Schwab
  # Main client for interacting with the Schwab API
  class Client
    attr_reader :access_token, :refresh_token, :auto_refresh, :config

    # Initialize a new Schwab API client
    #
    # @param access_token [String] OAuth access token
    # @param refresh_token [String, nil] OAuth refresh token for auto-refresh
    # @param auto_refresh [Boolean] Whether to automatically refresh expired tokens
    # @param on_token_refresh [Proc, nil] Callback when token is refreshed
    # @param config [Configuration, nil] Custom configuration (uses global if not provided)
    def initialize(access_token:, refresh_token: nil, auto_refresh: false, on_token_refresh: nil, config: nil)
      @access_token = access_token
      @refresh_token = refresh_token
      @auto_refresh = auto_refresh
      @on_token_refresh = on_token_refresh
      @config = config || Schwab.configuration || Configuration.new
      @connection = nil
      @mutex = Mutex.new
    end

    # Get the Faraday connection (lazily initialized)
    #
    # @return [Faraday::Connection] The configured HTTP connection
    def connection
      @mutex.synchronize do
        @connection ||= build_connection
      end
    end

    # Make a GET request to the API
    #
    # @param path [String] The API endpoint path
    # @param params [Hash] Query parameters
    # @return [Hash] The parsed response
    def get(path, params = {})
      request(:get, path, params)
    end

    # Make a POST request to the API
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] The parsed response
    def post(path, body = {})
      request(:post, path, body)
    end

    # Make a PUT request to the API
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] The parsed response
    def put(path, body = {})
      request(:put, path, body)
    end

    # Make a DELETE request to the API
    #
    # @param path [String] The API endpoint path
    # @param params [Hash] Query parameters
    # @return [Hash] The parsed response
    def delete(path, params = {})
      request(:delete, path, params)
    end

    # Make a PATCH request to the API
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] The parsed response
    def patch(path, body = {})
      request(:patch, path, body)
    end

    # Update the access token (useful after manual refresh)
    #
    # @param new_token [String] The new access token
    def update_access_token(new_token)
      @mutex.synchronize do
        @access_token = new_token
        @connection = nil # Force rebuild of connection with new token
      end
    end

    # Update both access and refresh tokens
    #
    # @param access_token [String] The new access token
    # @param refresh_token [String, nil] The new refresh token
    def update_tokens(access_token:, refresh_token: nil)
      @mutex.synchronize do
        @access_token = access_token
        @refresh_token = refresh_token if refresh_token
        @connection = nil # Force rebuild of connection
      end
    end

    private

    def build_connection
      if @auto_refresh && @refresh_token
        # Build connection with automatic token refresh
        Connection.build_with_refresh(
          access_token: @access_token,
          refresh_token: @refresh_token,
          on_token_refresh: method(:handle_token_refresh),
          config: @config,
        )
      else
        # Build standard connection
        Connection.build(
          access_token: @access_token,
          config: @config,
        )
      end
    end

    def handle_token_refresh(token_data)
      # Update our tokens
      @access_token = token_data[:access_token]
      @refresh_token = token_data[:refresh_token] if token_data[:refresh_token]

      # Call user's callback if provided
      @on_token_refresh&.call(token_data)
    end

    def request(method, path, params_or_body = {})
      # Remove leading slash if present to work with Faraday's URL joining
      path = path.sub(%r{^/}, "")

      response = case method
      when :get, :delete
        connection.send(method, path, params_or_body)
      when :post, :put, :patch
        connection.send(method, path, params_or_body)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end

      response.body
    rescue Faraday::Error => e
      handle_error(e)
    end

    def handle_error(error)
      case error
      when Faraday::TimeoutError, Faraday::ConnectionFailed
        raise Schwab::Error, "Request timeout: #{error.message}"
      when Faraday::UnauthorizedError
        raise Schwab::AuthenticationError, "Authentication failed: #{error.message}"
      when Faraday::ForbiddenError
        raise Schwab::AuthorizationError, "Access forbidden: #{error.message}"
      when Faraday::ResourceNotFound
        raise Schwab::NotFoundError, "Resource not found: #{error.message}"
      when Faraday::TooManyRequestsError
        raise Schwab::RateLimitError, "Rate limit exceeded: #{error.message}"
      when Faraday::ServerError
        raise Schwab::ServerError, "Server error: #{error.message}"
      else
        raise Schwab::Error, "Request failed: #{error.message}"
      end
    end
  end
end
