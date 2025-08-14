# frozen_string_literal: true

require_relative "connection"
require_relative "middleware/authentication"
require_relative "middleware/rate_limit"
require_relative "account_number_resolver"
require_relative "resources/base"
require_relative "resources/account"
require_relative "resources/position"
require_relative "resources/transaction"
require_relative "resources/order"
require_relative "resources/strategy"

module Schwab
  # Main client for interacting with the Schwab API
  class Client
    attr_reader :access_token, :refresh_token, :auto_refresh, :config, :account_resolver

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
      @account_resolver = nil
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
    # @param resource_class [Class, nil] Optional resource class for response wrapping
    # @return [Hash, Resources::Base] The response (hash or resource based on config)
    def get(path, params = {}, resource_class = nil)
      request(:get, path, params, resource_class)
    end

    # Make a POST request to the API
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body
    # @param resource_class [Class, nil] Optional resource class for response wrapping
    # @return [Hash, Resources::Base] The response (hash or resource based on config)
    def post(path, body = {}, resource_class = nil)
      request(:post, path, body, resource_class)
    end

    # Make a PUT request to the API
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body
    # @param resource_class [Class, nil] Optional resource class for response wrapping
    # @return [Hash, Resources::Base] The response (hash or resource based on config)
    def put(path, body = {}, resource_class = nil)
      request(:put, path, body, resource_class)
    end

    # Make a DELETE request to the API
    #
    # @param path [String] The API endpoint path
    # @param params [Hash] Query parameters
    # @param resource_class [Class, nil] Optional resource class for response wrapping
    # @return [Hash, Resources::Base] The response (hash or resource based on config)
    def delete(path, params = {}, resource_class = nil)
      request(:delete, path, params, resource_class)
    end

    # Make a PATCH request to the API
    #
    # @param path [String] The API endpoint path
    # @param body [Hash] Request body
    # @param resource_class [Class, nil] Optional resource class for response wrapping
    # @return [Hash, Resources::Base] The response (hash or resource based on config)
    def patch(path, body = {}, resource_class = nil)
      request(:patch, path, body, resource_class)
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

    # Get the account number resolver (lazily initialized)
    #
    # @return [AccountNumberResolver] The account number resolver
    def account_resolver
      @mutex.synchronize do
        @account_resolver ||= AccountNumberResolver.new(self)
      end
    end

    # Resolve an account number to its encrypted hash value
    #
    # @param account_number [String] Plain account number or encrypted hash
    # @return [String] The encrypted hash value for API calls
    # @example Resolve account number
    #   client.resolve_account_number("123456789")  # => "ABC123XYZ"
    def resolve_account_number(account_number)
      account_resolver.resolve(account_number)
    end

    # Refresh account number mappings
    #
    # @return [void]
    # @example Refresh account mappings
    #   client.refresh_account_mappings!
    def refresh_account_mappings!
      account_resolver.refresh!
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

    def request(method, path, params_or_body = {}, resource_class = nil)
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

      wrap_response(response.body, resource_class)
    rescue Faraday::Error => e
      handle_error(e)
    end

    # Wrap response data based on configured format
    #
    # @param data [Hash, Array] The response data
    # @param resource_class [Class, nil] Optional resource class to use for wrapping
    # @return [Hash, Array, Resources::Base] The wrapped response
    def wrap_response(data, resource_class = nil)
      return data if @config.response_format == :hash || data.nil?

      # If response_format is :resource, wrap the response
      if data.is_a?(Array)
        data.map { |item| wrap_single_response(item, resource_class) }
      else
        wrap_single_response(data, resource_class)
      end
    end

    # Wrap a single response item
    #
    # @param item [Hash] The response item
    # @param resource_class [Class, nil] Optional resource class to use
    # @return [Resources::Base] The wrapped response
    def wrap_single_response(item, resource_class)
      return item unless item.is_a?(Hash)

      klass = resource_class || determine_resource_class(item)
      klass.new(item, self)
    end

    # Determine the appropriate resource class based on response data
    #
    # @param data [Hash] The response data
    # @return [Class] The resource class to use
    def determine_resource_class(data)
      # Check for specific identifiers in the response to determine type
      if data.key?(:accountNumber) || data.key?(:account_number)
        Resources::Account
      elsif data.key?(:orderId) || data.key?(:order_id)
        Resources::Order
      elsif data.key?(:transactionId) || data.key?(:transaction_id)
        Resources::Transaction
      elsif data.key?(:instrument) && (data.key?(:longQuantity) || data.key?(:long_quantity))
        Resources::Position
      elsif data.key?(:strategyType) || data.key?(:strategy_type)
        Resources::Strategy
      else
        Resources::Base
      end
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
      when Faraday::BadRequestError
        # Preserve the response body for BadRequestError so we can parse JSON error details
        bad_request_error = Schwab::BadRequestError.new("Bad request: #{error.message}")
        bad_request_error.response_body = error.response[:body] if error.response && error.response[:body]
        raise bad_request_error
      when Faraday::ServerError
        raise Schwab::ServerError, "Server error: #{error.message}"
      else
        raise Schwab::Error, "Request failed: #{error.message}"
      end
    end
  end
end
