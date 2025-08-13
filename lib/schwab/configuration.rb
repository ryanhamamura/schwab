# frozen_string_literal: true

module Schwab
  # Configuration storage for Schwab SDK
  class Configuration
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

    def initialize
      @api_base_url = "https://api.schwabapi.com"
      @api_version = "v1"
      @timeout = 30
      @open_timeout = 30
      @faraday_adapter = Faraday.default_adapter
      @max_retries = 3
      @retry_delay = 1
      @logger = nil
    end

    # Get the full API endpoint URL with version
    def api_endpoint
      "#{api_base_url}/#{api_version}"
    end

    # OAuth-specific endpoints
    def oauth_authorize_url
      "#{api_base_url}/v1/oauth/authorize"
    end

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
      }
    end
  end
end
