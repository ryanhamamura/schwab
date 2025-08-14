# frozen_string_literal: true

module Schwab
  # Configuration storage for Schwab SDK
  #
  # @example Configure the SDK
  #   Schwab.configure do |config|
  #     config.client_id = "your_client_id"
  #     config.client_secret = "your_client_secret"
  #     config.redirect_uri = "http://localhost:3000/callback"
  #     config.response_format = :hash # or :resource
  #   end
  class Configuration
    # @!attribute client_id
    #   @return [String] OAuth client ID from Schwab developer portal
    # @!attribute client_secret
    #   @return [String] OAuth client secret from Schwab developer portal
    # @!attribute redirect_uri
    #   @return [String] OAuth callback URL configured in Schwab developer portal
    # @!attribute api_base_url
    #   @return [String] Base URL for Schwab API (default: https://api.schwabapi.com)
    # @!attribute api_version
    #   @return [String] API version to use (default: v1)
    # @!attribute logger
    #   @return [Logger, nil] Logger instance for debugging
    # @!attribute timeout
    #   @return [Integer] Request timeout in seconds (default: 30)
    # @!attribute open_timeout
    #   @return [Integer] Connection open timeout in seconds (default: 30)
    # @!attribute faraday_adapter
    #   @return [Symbol] Faraday adapter to use (default: Faraday.default_adapter)
    # @!attribute max_retries
    #   @return [Integer] Maximum number of retries for failed requests (default: 3)
    # @!attribute retry_delay
    #   @return [Integer] Delay in seconds between retries (default: 1)
    # @!attribute response_format
    #   @return [Symbol] Response format (:hash or :resource, default: :hash)
    #     - :hash returns plain Ruby hashes (default, backward compatible)
    #     - :resource returns Sawyer::Resource-like objects with method access
    attr_accessor :client_id,
      :client_secret,
      :redirect_uri,
      :api_base_url,
      :api_version,
      :logger,
      :timeout,
      :open_timeout,
      :faraday_adapter,
      :max_retries,
      :retry_delay

    attr_reader :response_format

    def initialize
      @api_base_url = "https://api.schwabapi.com"
      @api_version = "v1"
      @timeout = 30
      @open_timeout = 30
      @faraday_adapter = Faraday.default_adapter
      @max_retries = 3
      @retry_delay = 1
      @logger = nil
      @response_format = :hash
    end

    # Set response format with validation
    #
    # @param format [Symbol] The response format to use (:hash or :resource)
    # @raise [ArgumentError] if format is not :hash or :resource
    # @example Set response format to resource objects
    #   config.response_format = :resource
    def response_format=(format)
      valid_formats = [:hash, :resource]
      unless valid_formats.include?(format)
        raise ArgumentError, "Invalid response_format: #{format}. Must be :hash or :resource"
      end

      @response_format = format
    end

    # Get the full API endpoint URL with version
    def api_endpoint
      "#{api_base_url}/#{api_version}"
    end

    # OAuth-specific endpoints
    # @return [String] The OAuth authorization URL
    def oauth_authorize_url
      "#{api_base_url}/v1/oauth/authorize"
    end

    # Get the OAuth token endpoint URL
    # @return [String] The OAuth token URL
    def oauth_token_url
      "#{api_base_url}/v1/oauth/token"
    end

    # Validate that required OAuth parameters are present
    def validate!
      missing = []
      missing << "client_id" if client_id.nil? || client_id.empty?
      missing << "client_secret" if client_secret.nil? || client_secret.empty?
      missing << "redirect_uri" if redirect_uri.nil? || redirect_uri.empty?

      unless missing.empty?
        raise Error, "Missing required configuration: #{missing.join(", ")}"
      end

      # Validate response_format
      valid_formats = [:hash, :resource]
      unless valid_formats.include?(response_format)
        raise Error, "Invalid response_format: #{response_format}. Must be :hash or :resource"
      end

      true
    end

    # Check if OAuth credentials are configured
    def oauth_configured?
      !client_id.nil? && !client_secret.nil? && !redirect_uri.nil?
    end

    # Convert configuration to a hash
    def to_h
      {
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        api_base_url: api_base_url,
        timeout: timeout,
        open_timeout: open_timeout,
        faraday_adapter: faraday_adapter,
        max_retries: max_retries,
        retry_delay: retry_delay,
        logger: logger,
        response_format: response_format,
      }
    end
  end
end
