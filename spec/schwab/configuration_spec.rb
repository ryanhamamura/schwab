# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Schwab::Configuration) do
  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.api_base_url).to(eq("https://api.schwabapi.com"))
      expect(config.api_version).to(eq("v1"))
      expect(config.timeout).to(eq(30))
      expect(config.open_timeout).to(eq(30))
      expect(config.max_retries).to(eq(3))
      expect(config.retry_delay).to(eq(1))
      expect(config.logger).to(be_nil)
      expect(config.faraday_adapter).to(eq(Faraday.default_adapter))
      expect(config.response_format).to(eq(:hash))
    end
  end

  describe "#response_format=" do
    it "accepts :hash format" do
      config = described_class.new
      config.response_format = :hash
      expect(config.response_format).to(eq(:hash))
    end

    it "accepts :resource format" do
      config = described_class.new
      config.response_format = :resource
      expect(config.response_format).to(eq(:resource))
    end

    it "raises ArgumentError for invalid format" do
      config = described_class.new
      expect { config.response_format = :invalid }.to(raise_error(
        ArgumentError,
        "Invalid response_format: invalid. Must be :hash or :resource",
      ))
    end

    it "raises ArgumentError for nil format" do
      config = described_class.new
      expect { config.response_format = nil }.to(raise_error(
        ArgumentError,
        "Invalid response_format: . Must be :hash or :resource",
      ))
    end
  end

  describe "#api_endpoint" do
    it "combines base URL and version" do
      config = described_class.new
      expect(config.api_endpoint).to(eq("https://api.schwabapi.com/v1"))
    end

    it "uses custom values when set" do
      config = described_class.new
      config.api_base_url = "https://sandbox.schwabapi.com"
      config.api_version = "v2"

      expect(config.api_endpoint).to(eq("https://sandbox.schwabapi.com/v2"))
    end
  end

  describe "#oauth_authorize_url" do
    it "returns the OAuth authorization endpoint" do
      config = described_class.new
      expect(config.oauth_authorize_url).to(eq("https://api.schwabapi.com/v1/oauth/authorize"))
    end
  end

  describe "#oauth_token_url" do
    it "returns the OAuth token endpoint" do
      config = described_class.new
      expect(config.oauth_token_url).to(eq("https://api.schwabapi.com/v1/oauth/token"))
    end
  end

  describe "#validate!" do
    context "with all required parameters" do
      it "returns true" do
        config = described_class.new
        config.client_id = "test_id"
        config.client_secret = "test_secret"
        config.redirect_uri = "http://localhost:3000/callback"

        expect(config.validate!).to(eq(true))
      end
    end

    context "with missing client_id" do
      it "raises an error" do
        config = described_class.new
        config.client_secret = "test_secret"
        config.redirect_uri = "http://localhost:3000/callback"

        expect { config.validate! }.to(raise_error(
          Schwab::Error,
          "Missing required configuration: client_id",
        ))
      end
    end

    context "with missing client_secret" do
      it "raises an error" do
        config = described_class.new
        config.client_id = "test_id"
        config.redirect_uri = "http://localhost:3000/callback"

        expect { config.validate! }.to(raise_error(
          Schwab::Error,
          "Missing required configuration: client_secret",
        ))
      end
    end

    context "with missing redirect_uri" do
      it "raises an error" do
        config = described_class.new
        config.client_id = "test_id"
        config.client_secret = "test_secret"

        expect { config.validate! }.to(raise_error(
          Schwab::Error,
          "Missing required configuration: redirect_uri",
        ))
      end
    end

    context "with multiple missing parameters" do
      it "lists all missing parameters in the error" do
        config = described_class.new
        config.client_id = "test_id"

        expect { config.validate! }.to(raise_error(
          Schwab::Error,
          "Missing required configuration: client_secret, redirect_uri",
        ))
      end
    end

    context "with empty strings" do
      it "treats empty strings as missing" do
        config = described_class.new
        config.client_id = ""
        config.client_secret = "test_secret"
        config.redirect_uri = "http://localhost:3000/callback"

        expect { config.validate! }.to(raise_error(
          Schwab::Error,
          "Missing required configuration: client_id",
        ))
      end
    end

    context "with invalid response_format" do
      it "raises an error for invalid format" do
        config = described_class.new
        config.client_id = "test_id"
        config.client_secret = "test_secret"
        config.redirect_uri = "http://localhost:3000/callback"
        config.instance_variable_set(:@response_format, :invalid)

        expect { config.validate! }.to(raise_error(
          Schwab::Error,
          "Invalid response_format: invalid. Must be :hash or :resource",
        ))
      end
    end

    context "with valid response_format" do
      it "validates successfully with :hash format" do
        config = described_class.new
        config.client_id = "test_id"
        config.client_secret = "test_secret"
        config.redirect_uri = "http://localhost:3000/callback"
        config.response_format = :hash

        expect(config.validate!).to(eq(true))
      end

      it "validates successfully with :resource format" do
        config = described_class.new
        config.client_id = "test_id"
        config.client_secret = "test_secret"
        config.redirect_uri = "http://localhost:3000/callback"
        config.response_format = :resource

        expect(config.validate!).to(eq(true))
      end
    end
  end

  describe "#oauth_configured?" do
    it "returns true when all OAuth parameters are set" do
      config = described_class.new
      config.client_id = "test_id"
      config.client_secret = "test_secret"
      config.redirect_uri = "http://localhost:3000/callback"

      expect(config.oauth_configured?).to(eq(true))
    end

    it "returns false when any OAuth parameter is missing" do
      config = described_class.new
      config.client_id = "test_id"
      config.client_secret = "test_secret"
      # redirect_uri is missing

      expect(config.oauth_configured?).to(eq(false))
    end
  end

  describe "#to_h" do
    it "returns all configuration as a hash" do
      config = described_class.new
      config.client_id = "test_id"
      config.client_secret = "test_secret"
      config.redirect_uri = "http://localhost:3000/callback"
      config.logger = Logger.new(nil)

      hash = config.to_h

      expect(hash).to(be_a(Hash))
      expect(hash[:client_id]).to(eq("test_id"))
      expect(hash[:client_secret]).to(eq("test_secret"))
      expect(hash[:redirect_uri]).to(eq("http://localhost:3000/callback"))
      expect(hash[:api_base_url]).to(eq("https://api.schwabapi.com"))
      expect(hash[:timeout]).to(eq(30))
      expect(hash[:open_timeout]).to(eq(30))
      expect(hash[:max_retries]).to(eq(3))
      expect(hash[:retry_delay]).to(eq(1))
      expect(hash[:logger]).to(be_a(Logger))
      expect(hash[:response_format]).to(eq(:hash))
    end
  end
end
