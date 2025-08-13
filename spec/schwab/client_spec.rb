# frozen_string_literal: true

require "spec_helper"
require "schwab/client"

RSpec.describe(Schwab::Client) do
  let(:access_token) { "test_access_token" }
  let(:refresh_token) { "test_refresh_token" }
  let(:config) do
    Schwab::Configuration.new.tap do |c|
      c.api_base_url = "https://api.test.com"
      c.api_version = "v1"
      c.client_id = "test_client_id"
      c.client_secret = "test_client_secret"
    end
  end

  describe "#initialize" do
    it "initializes with an access token" do
      client = described_class.new(access_token: access_token)

      expect(client.access_token).to(eq(access_token))
      expect(client.refresh_token).to(be_nil)
      expect(client.auto_refresh).to(be(false))
    end

    it "initializes with all options" do
      callback = proc { |token| puts token }

      client = described_class.new(
        access_token: access_token,
        refresh_token: refresh_token,
        auto_refresh: true,
        on_token_refresh: callback,
        config: config,
      )

      expect(client.access_token).to(eq(access_token))
      expect(client.refresh_token).to(eq(refresh_token))
      expect(client.auto_refresh).to(be(true))
      expect(client.config).to(eq(config))
    end

    it "uses global configuration when config not provided" do
      Schwab.configure do |c|
        c.api_base_url = "https://global.test.com"
      end

      client = described_class.new(access_token: access_token)
      expect(client.config.api_base_url).to(eq("https://global.test.com"))

      Schwab.reset_configuration!
    end
  end

  describe "#connection" do
    let(:client) { described_class.new(access_token: access_token, config: config) }

    it "returns a Faraday connection" do
      expect(client.connection).to(be_a(Faraday::Connection))
    end

    it "lazily initializes the connection" do
      expect(Schwab::Connection).to(receive(:build).once.and_call_original)

      # First call creates the connection
      connection1 = client.connection
      # Second call returns the same connection
      connection2 = client.connection

      expect(connection1).to(equal(connection2))
    end

    it "is thread-safe" do
      connections = []
      threads = []

      5.times do
        threads << Thread.new do
          connections << client.connection
        end
      end

      threads.each(&:join)

      # All threads should get the same connection instance
      expect(connections.uniq.size).to(eq(1))
    end

    context "with auto_refresh enabled" do
      let(:client) do
        described_class.new(
          access_token: access_token,
          refresh_token: refresh_token,
          auto_refresh: true,
          config: config,
        )
      end

      it "builds a connection with refresh capability" do
        expect(Schwab::Connection).to(receive(:build_with_refresh).and_call_original)
        client.connection
      end
    end
  end

  describe "HTTP methods" do
    let(:client) { described_class.new(access_token: access_token, config: config) }
    let(:response_body) { { "data" => "test" } }

    before do
      stub_request(:any, /api.test.com/)
        .to_return(
          status: 200,
          body: response_body.to_json,
          headers: { "Content-Type" => "application/json" },
        )
    end

    describe "#get" do
      it "makes a GET request" do
        result = client.get("/test", { param: "value" })

        expect(WebMock).to(have_requested(:get, "https://api.test.com/v1/test")
          .with(query: { param: "value" }))
        expect(result).to(eq(response_body))
      end
    end

    describe "#post" do
      it "makes a POST request" do
        body = { key: "value" }
        result = client.post("/test", body)

        expect(WebMock).to(have_requested(:post, "https://api.test.com/v1/test")
          .with(body: body.to_json))
        expect(result).to(eq(response_body))
      end
    end

    describe "#put" do
      it "makes a PUT request" do
        body = { key: "value" }
        result = client.put("/test", body)

        expect(WebMock).to(have_requested(:put, "https://api.test.com/v1/test")
          .with(body: body.to_json))
        expect(result).to(eq(response_body))
      end
    end

    describe "#delete" do
      it "makes a DELETE request" do
        result = client.delete("/test", { param: "value" })

        expect(WebMock).to(have_requested(:delete, "https://api.test.com/v1/test")
          .with(query: { param: "value" }))
        expect(result).to(eq(response_body))
      end
    end

    describe "#patch" do
      it "makes a PATCH request" do
        body = { key: "value" }
        result = client.patch("/test", body)

        expect(WebMock).to(have_requested(:patch, "https://api.test.com/v1/test")
          .with(body: body.to_json))
        expect(result).to(eq(response_body))
      end
    end
  end

  describe "#update_access_token" do
    let(:client) { described_class.new(access_token: access_token, config: config) }
    let(:new_token) { "new_access_token" }

    it "updates the access token" do
      client.update_access_token(new_token)
      expect(client.access_token).to(eq(new_token))
    end

    it "resets the connection" do
      # Get initial connection
      connection1 = client.connection

      # Update token
      client.update_access_token(new_token)

      # Connection should be rebuilt
      expect(Schwab::Connection).to(receive(:build).and_call_original)
      connection2 = client.connection

      expect(connection1).not_to(equal(connection2))
    end
  end

  describe "#update_tokens" do
    let(:client) { described_class.new(access_token: access_token, config: config) }
    let(:new_access_token) { "new_access_token" }
    let(:new_refresh_token) { "new_refresh_token" }

    it "updates both tokens" do
      client.update_tokens(
        access_token: new_access_token,
        refresh_token: new_refresh_token,
      )

      expect(client.access_token).to(eq(new_access_token))
      expect(client.refresh_token).to(eq(new_refresh_token))
    end

    it "updates only access token when refresh not provided" do
      original_refresh = client.refresh_token

      client.update_tokens(access_token: new_access_token)

      expect(client.access_token).to(eq(new_access_token))
      expect(client.refresh_token).to(eq(original_refresh))
    end
  end

  describe "error handling" do
    let(:client) { described_class.new(access_token: access_token, config: config) }

    context "when API returns 401" do
      before do
        stub_request(:get, "https://api.test.com/v1/test")
          .to_return(status: 401, body: "Unauthorized")
      end

      it "raises AuthenticationError" do
        expect { client.get("/test") }.to(raise_error(Schwab::AuthenticationError))
      end
    end

    context "when API returns 403" do
      before do
        stub_request(:get, "https://api.test.com/v1/test")
          .to_return(status: 403, body: "Forbidden")
      end

      it "raises AuthorizationError" do
        expect { client.get("/test") }.to(raise_error(Schwab::AuthorizationError))
      end
    end

    context "when API returns 404" do
      before do
        stub_request(:get, "https://api.test.com/v1/test")
          .to_return(status: 404, body: "Not Found")
      end

      it "raises NotFoundError" do
        expect { client.get("/test") }.to(raise_error(Schwab::NotFoundError))
      end
    end

    context "when API returns 429" do
      before do
        stub_request(:get, "https://api.test.com/v1/test")
          .to_return(status: 429, body: "Too Many Requests")
      end

      it "raises RateLimitError" do
        expect { client.get("/test") }.to(raise_error(Schwab::RateLimitError))
      end
    end

    context "when API returns 500" do
      before do
        stub_request(:get, "https://api.test.com/v1/test")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises ServerError" do
        expect { client.get("/test") }.to(raise_error(Schwab::ServerError))
      end
    end

    context "when request times out" do
      before do
        stub_request(:get, "https://api.test.com/v1/test").to_timeout
      end

      it "raises Schwab::Error with timeout message" do
        expect { client.get("/test") }.to(raise_error(Schwab::Error, /timeout/i))
      end
    end
  end

  describe "token refresh callback" do
    let(:callback_spy) { double("callback", call: nil) }
    let(:client) do
      described_class.new(
        access_token: access_token,
        refresh_token: refresh_token,
        auto_refresh: true,
        on_token_refresh: callback_spy,
        config: config,
      )
    end

    it "calls the callback when tokens are refreshed" do
      token_data = {
        access_token: "new_token",
        refresh_token: "new_refresh",
        expires_in: 3600,
      }

      # Simulate token refresh by calling the private method
      client.send(:handle_token_refresh, token_data)

      expect(callback_spy).to(have_received(:call).with(token_data))
      expect(client.access_token).to(eq("new_token"))
      expect(client.refresh_token).to(eq("new_refresh"))
    end
  end
end
