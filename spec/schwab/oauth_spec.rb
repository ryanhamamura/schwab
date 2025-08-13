# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Schwab::OAuth) do
  describe ".authorization_url" do
    let(:client_id) { "test_client_id" }
    let(:redirect_uri) { "http://localhost:3000/callback" }

    it "generates a valid authorization URL with required parameters" do
      url = described_class.authorization_url(
        client_id: client_id,
        redirect_uri: redirect_uri,
      )

      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(uri.scheme).to(eq("https"))
      expect(uri.host).to(eq("api.schwabapi.com"))
      expect(uri.path).to(eq("/v1/oauth/authorize"))
      expect(params["response_type"]).to(eq("code"))
      expect(params["client_id"]).to(eq(client_id))
      expect(params["redirect_uri"]).to(eq(redirect_uri))
      expect(params["state"]).to(be_a(String))
      expect(params["state"].length).to(eq(32)) # SecureRandom.hex(16) generates 32 chars
    end

    it "uses provided state parameter when given" do
      custom_state = "custom_state_123"
      url = described_class.authorization_url(
        client_id: client_id,
        redirect_uri: redirect_uri,
        state: custom_state,
      )

      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query).to_h

      expect(params["state"]).to(eq(custom_state))
    end

    it "generates different state values for each call when not provided" do
      url1 = described_class.authorization_url(
        client_id: client_id,
        redirect_uri: redirect_uri,
      )
      url2 = described_class.authorization_url(
        client_id: client_id,
        redirect_uri: redirect_uri,
      )

      state1 = URI.decode_www_form(URI.parse(url1).query).to_h["state"]
      state2 = URI.decode_www_form(URI.parse(url2).query).to_h["state"]

      expect(state1).not_to(eq(state2))
    end

    context "with custom configuration" do
      let(:custom_config) do
        Schwab::Configuration.new.tap do |c|
          c.api_base_url = "https://sandbox.schwabapi.com"
          c.api_version = "v2"
        end
      end

      it "uses custom base URL and version from configuration" do
        url = described_class.authorization_url(
          client_id: client_id,
          redirect_uri: redirect_uri,
          config: custom_config,
        )

        uri = URI.parse(url)
        expect(uri.host).to(eq("sandbox.schwabapi.com"))
        expect(uri.path).to(eq("/v2/oauth/authorize"))
      end
    end

    context "with global configuration" do
      before do
        Schwab.configure do |config|
          config.api_base_url = "https://test.schwabapi.com"
          config.api_version = "v3"
        end
      end

      after do
        Schwab.reset_configuration!
      end

      it "uses global configuration when no config is provided" do
        url = described_class.authorization_url(
          client_id: client_id,
          redirect_uri: redirect_uri,
        )

        uri = URI.parse(url)
        expect(uri.host).to(eq("test.schwabapi.com"))
        expect(uri.path).to(eq("/v3/oauth/authorize"))
      end
    end
  end

  describe ".get_token" do
    let(:client_id) { ENV["SCHWAB_CLIENT_ID"] || "test_client_id" }
    let(:client_secret) { ENV["SCHWAB_CLIENT_SECRET"] || "test_client_secret" }
    let(:redirect_uri) { ENV["SCHWAB_REDIRECT_URI"] || "http://localhost:3000/callback" }
    let(:authorization_code) { "test_authorization_code" }

    context "with valid authorization code", :vcr do
      it "exchanges authorization code for access and refresh tokens" do
        # This test will only work with real credentials and a valid auth code
        # When running for the first time, you'll need to:
        # 1. Set SCHWAB_CLIENT_ID, SCHWAB_CLIENT_SECRET, SCHWAB_REDIRECT_URI env vars
        # 2. Get a fresh authorization code from Schwab OAuth flow
        # 3. Set the authorization_code variable above
        # 4. Run the test to record the VCR cassette

        skip "Requires real Schwab credentials and valid authorization code" unless ENV["SCHWAB_CLIENT_ID"]

        result = described_class.get_token(
          code: authorization_code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri,
        )

        expect(result).to(be_a(Hash))
        expect(result[:access_token]).to(be_a(String))
        expect(result[:refresh_token]).to(be_a(String))
        expect(result[:expires_in]).to(be_a(Integer))
        expect(result[:expires_at]).to(be_a(Time))
        expect(result[:token_type]).to(eq("Bearer"))
      end
    end

    context "with invalid authorization code" do
      it "raises an OAuth2 error" do
        # Use WebMock to stub the request for this test
        stub_request(:post, "https://api.schwabapi.com/v1/oauth/token")
          .with(
            body: hash_including(
              "grant_type" => "authorization_code",
              "code" => "invalid_code",
            ),
          )
          .to_return(
            status: 400,
            body: { error: "invalid_grant", error_description: "Invalid authorization code" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

        expect do
          described_class.get_token(
            code: "invalid_code",
            client_id: client_id,
            client_secret: client_secret,
            redirect_uri: redirect_uri,
          )
        end.to(raise_error(OAuth2::Error))
      end
    end
  end

  describe ".refresh_token" do
    let(:client_id) { ENV["SCHWAB_CLIENT_ID"] || "test_client_id" }
    let(:client_secret) { ENV["SCHWAB_CLIENT_SECRET"] || "test_client_secret" }
    let(:refresh_token) { "test_refresh_token" }

    context "with valid refresh token", :vcr do
      it "exchanges refresh token for new access token" do
        # This test requires a valid refresh token from a previous OAuth flow
        skip "Requires real Schwab credentials and valid refresh token" unless ENV["SCHWAB_CLIENT_ID"]

        result = described_class.refresh_token(
          refresh_token: refresh_token,
          client_id: client_id,
          client_secret: client_secret,
        )

        expect(result).to(be_a(Hash))
        expect(result[:access_token]).to(be_a(String))
        expect(result[:refresh_token]).to(be_a(String))
        expect(result[:expires_in]).to(be_a(Integer))
        expect(result[:expires_at]).to(be_a(Time))
        expect(result[:token_type]).to(eq("Bearer"))
      end
    end

    context "with invalid refresh token" do
      it "raises an OAuth2 error" do
        stub_request(:post, "https://api.schwabapi.com/v1/oauth/token")
          .with(
            body: hash_including(
              "grant_type" => "refresh_token",
              "refresh_token" => "invalid_refresh_token",
            ),
          )
          .to_return(
            status: 400,
            body: { error: "invalid_grant", error_description: "Invalid refresh token" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

        expect do
          described_class.refresh_token(
            refresh_token: "invalid_refresh_token",
            client_id: client_id,
            client_secret: client_secret,
          )
        end.to(raise_error(OAuth2::Error))
      end
    end
  end
end
