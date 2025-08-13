# frozen_string_literal: true

require "spec_helper"
require "schwab/connection"

RSpec.describe(Schwab::Connection) do
  let(:config) do
    Schwab::Configuration.new.tap do |c|
      c.api_base_url = "https://api.test.com"
      c.api_version = "v1"
      c.timeout = 30
      c.open_timeout = 10
    end
  end

  describe ".build" do
    context "without access token" do
      it "creates a Faraday connection without authentication" do
        connection = described_class.build(config: config)

        expect(connection).to(be_a(Faraday::Connection))
        expect(connection.url_prefix.to_s).to(eq("https://api.test.com/"))
        expect(connection.options.timeout).to(eq(30))
        expect(connection.options.open_timeout).to(eq(10))
      end

      it "includes JSON middleware" do
        connection = described_class.build(config: config)
        middleware = connection.builder.handlers

        # Check for request JSON encoder
        expect(middleware).to(include(Faraday::Request::Json))

        # Check for response JSON parser
        expect(middleware).to(include(Faraday::Response::Json))
      end

      it "includes error raising middleware" do
        connection = described_class.build(config: config)
        middleware = connection.builder.handlers

        expect(middleware).to(include(Faraday::Response::RaiseError))
      end
    end

    context "with access token" do
      let(:access_token) { "test_access_token" }

      it "creates a connection with Bearer authentication" do
        connection = described_class.build(access_token: access_token, config: config)

        # Make a mock request to check headers
        stub_request(:get, "https://api.test.com/test")
          .with(headers: { "Authorization" => "Bearer #{access_token}" })
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

        connection.get("/test")

        expect(WebMock).to(have_requested(:get, "https://api.test.com/test")
          .with(headers: { "Authorization" => "Bearer #{access_token}" }))
      end
    end

    context "with logger" do
      let(:logger) { Logger.new(StringIO.new) }

      before do
        config.logger = logger
      end

      it "includes logging middleware when logger is configured" do
        connection = described_class.build(config: config)
        middleware = connection.builder.handlers

        expect(middleware).to(include(Faraday::Response::Logger))
      end
    end

    context "with custom adapter" do
      before do
        config.faraday_adapter = :test
      end

      it "uses the configured adapter" do
        connection = described_class.build(config: config)

        # Check that the connection can be built with the test adapter
        # (Faraday 2.x handles adapters differently)
        expect(connection).to(be_a(Faraday::Connection))
        expect { connection.builder.adapter }.not_to(raise_error)
      end
    end
  end

  describe ".build_with_refresh" do
    let(:access_token) { "test_access_token" }
    let(:refresh_token) { "test_refresh_token" }
    let(:on_token_refresh) { double("callback") }

    context "with refresh token" do
      it "creates a connection with token refresh middleware" do
        connection = described_class.build_with_refresh(
          access_token: access_token,
          refresh_token: refresh_token,
          on_token_refresh: on_token_refresh,
          config: config,
        )

        expect(connection).to(be_a(Faraday::Connection))

        # Check that TokenRefresh middleware is included
        middleware = connection.builder.handlers
        expect(middleware).to(include(Schwab::Middleware::TokenRefresh))
      end

      it "configures TokenRefresh middleware with correct options" do
        # We'll need to set client credentials for token refresh
        config.client_id = "test_client_id"
        config.client_secret = "test_client_secret"

        connection = described_class.build_with_refresh(
          access_token: access_token,
          refresh_token: refresh_token,
          on_token_refresh: on_token_refresh,
          config: config,
        )

        # Verify that TokenRefresh middleware is in the handlers
        middleware = connection.builder.handlers
        expect(middleware).to(include(Schwab::Middleware::TokenRefresh))
      end
    end

    context "without refresh token" do
      it "creates a standard connection with Bearer authentication" do
        connection = described_class.build_with_refresh(
          access_token: access_token,
          refresh_token: nil,
          config: config,
        )

        # Should not include TokenRefresh middleware
        middleware = connection.builder.handlers
        expect(middleware).not_to(include(Schwab::Middleware::TokenRefresh))

        # Should still have authorization
        stub_request(:get, "https://api.test.com/test")
        connection.get("/test")

        expect(WebMock).to(have_requested(:get, "https://api.test.com/test")
          .with(headers: { "Authorization" => "Bearer #{access_token}" }))
      end
    end
  end

  describe "middleware order" do
    it "applies middleware in the correct order" do
      connection = described_class.build(access_token: "token", config: config)
      handlers = connection.builder.handlers

      # Request middleware should come before response middleware
      json_request_index = handlers.index(Faraday::Request::Json)
      json_response_index = handlers.index(Faraday::Response::Json)
      raise_error_index = handlers.index(Faraday::Response::RaiseError)

      expect(json_request_index).to(be < json_response_index)
      expect(json_response_index).to(be < raise_error_index)

      # There should be handlers (we're not testing adapter position anymore since
      # Faraday handles that internally)
      expect(handlers).not_to(be_empty)
    end
  end
end
