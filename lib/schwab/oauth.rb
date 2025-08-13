# frozen_string_literal: true

require "oauth2"
require "uri"
require "securerandom"

module Schwab
  # OAuth 2.0 authentication helpers for Schwab API
  module OAuth
    class << self
      # Generate the authorization URL for the OAuth 2.0 flow
      #
      # @param client_id [String] Your Schwab application's client ID
      # @param redirect_uri [String] The redirect URI configured in your Schwab application
      # @param state [String, nil] Optional state parameter for CSRF protection (will be generated if not provided)
      # @param config [Configuration, nil] Optional configuration object (uses global config if not provided)
      # @return [String] The authorization URL to redirect the user to
      def authorization_url(client_id:, redirect_uri:, state: nil, config: nil)
        config ||= Schwab.configuration || Configuration.new
        state ||= SecureRandom.hex(16)

        params = {
          response_type: "code",
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
        }

        uri = URI(config.oauth_authorize_url)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      # Exchange an authorization code for access and refresh tokens
      #
      # @param code [String] The authorization code from the OAuth callback
      # @param client_id [String] Your Schwab application's client ID
      # @param client_secret [String] Your Schwab application's client secret
      # @param redirect_uri [String] The redirect URI used in the authorization request
      # @param config [Configuration, nil] Optional configuration object (uses global config if not provided)
      # @return [Hash] Token response with :access_token, :refresh_token, :expires_in, :expires_at
      def get_token(code:, client_id:, client_secret:, redirect_uri:, config: nil)
        config ||= Schwab.configuration || Configuration.new
        client = oauth2_client(client_id: client_id, client_secret: client_secret, config: config)

        token = client.auth_code.get_token(
          code,
          redirect_uri: redirect_uri,
          headers: { "Content-Type" => "application/x-www-form-urlencoded" },
        )

        parse_token_response(token)
      end

      # Refresh an access token using a refresh token
      #
      # @param refresh_token [String] The refresh token
      # @param client_id [String] Your Schwab application's client ID
      # @param client_secret [String] Your Schwab application's client secret
      # @param config [Configuration, nil] Optional configuration object (uses global config if not provided)
      # @return [Hash] Token response with :access_token, :refresh_token, :expires_in, :expires_at
      def refresh_token(refresh_token:, client_id:, client_secret:, config: nil)
        config ||= Schwab.configuration || Configuration.new
        client = oauth2_client(client_id: client_id, client_secret: client_secret, config: config)

        token = OAuth2::AccessToken.new(client, nil, refresh_token: refresh_token)
        new_token = token.refresh!

        parse_token_response(new_token)
      end

      private

      def oauth2_client(client_id:, client_secret:, config:)
        OAuth2::Client.new(
          client_id,
          client_secret,
          site: config.api_base_url,
          authorize_url: config.oauth_authorize_url,
          token_url: config.oauth_token_url,
        )
      end

      def parse_token_response(token)
        {
          access_token: token.token,
          refresh_token: token.refresh_token,
          expires_in: token.expires_in,
          expires_at: token.expires_at ? Time.at(token.expires_at) : nil,
          token_type: token.params["token_type"] || "Bearer",
        }
      end
    end
  end
end
