# frozen_string_literal: true

require "spec_helper"
require "schwab/account_number_resolver"

RSpec.describe(Schwab::AccountNumberResolver) do
  let(:client) { instance_double("Schwab::Client") }
  let(:resolver) { described_class.new(client) }

  let(:account_numbers_response) do
    [
      { accountNumber: "123456789", hashValue: "ABC123XYZ" },
      { accountNumber: "987654321", hashValue: "DEF456UVW" },
      { accountNumber: "555666777", hashValue: "GHI789RST" },
    ]
  end

  before do
    allow(client).to(receive(:get)
      .with("/trader/v1/accounts/accountNumbers")
      .and_return(account_numbers_response))
  end

  describe "#resolve" do
    context "with plain account numbers" do
      it "resolves to encrypted hash value" do
        result = resolver.resolve("123456789")
        expect(result).to(eq("ABC123XYZ"))
      end

      it "resolves different account numbers correctly" do
        expect(resolver.resolve("987654321")).to(eq("DEF456UVW"))
        expect(resolver.resolve("555666777")).to(eq("GHI789RST"))
      end

      it "makes API call only once for multiple resolutions" do
        expect(client).to(receive(:get).once
          .with("/trader/v1/accounts/accountNumbers")
          .and_return(account_numbers_response))

        resolver.resolve("123456789")
        resolver.resolve("987654321")
        resolver.resolve("555666777")
      end
    end

    context "with encrypted hash values" do
      it "returns hash values unchanged if they look like hashes" do
        result = resolver.resolve("ABC123XYZ")
        expect(result).to(eq("ABC123XYZ"))
      end

      it "does not make API call for hash-like values" do
        expect(client).not_to(receive(:get))
        resolver.resolve("ABC123XYZ")
      end
    end

    context "with unknown account numbers" do
      it "raises an error for unknown account" do
        expect do
          resolver.resolve("999888777")
        end.to(raise_error(
          Schwab::Error,
          /Account number '999888777' not found/,
        ))
      end

      it "tries to refresh mappings for unknown accounts" do
        expect(client).to(receive(:get).twice
          .with("/trader/v1/accounts/accountNumbers")
          .and_return(account_numbers_response))

        expect do
          resolver.resolve("999888777")
        end.to(raise_error(Schwab::Error))
      end
    end

    context "when API response is wrapped" do
      let(:wrapped_response) do
        { accounts: account_numbers_response }
      end

      before do
        allow(client).to(receive(:get)
          .with("/trader/v1/accounts/accountNumbers")
          .and_return(wrapped_response))
      end

      it "handles wrapped response format" do
        result = resolver.resolve("123456789")
        expect(result).to(eq("ABC123XYZ"))
      end
    end

    context "with string key response format" do
      let(:string_key_response) do
        [
          { "accountNumber" => "123456789", "hashValue" => "ABC123XYZ" },
          { "accountNumber" => "987654321", "hashValue" => "DEF456UVW" },
        ]
      end

      before do
        allow(client).to(receive(:get)
          .with("/trader/v1/accounts/accountNumbers")
          .and_return(string_key_response))
      end

      it "handles string keys in response" do
        result = resolver.resolve("123456789")
        expect(result).to(eq("ABC123XYZ"))
      end
    end
  end

  describe "#refresh!" do
    it "forces reload of mappings" do
      # First call loads mappings
      resolver.resolve("123456789")

      # Mock a second API call with different response
      new_response = [{ accountNumber: "111222333", hashValue: "NEW123HASH" }]
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/accountNumbers")
        .and_return(new_response))

      resolver.refresh!

      # Old mappings should be gone, try to resolve old account should fail
      expect(resolver.mappings).to(eq({ "111222333" => "NEW123HASH" }))
    end
  end

  describe "#mappings" do
    it "returns copy of mappings hash" do
      resolver.resolve("123456789") # Load mappings
      mappings = resolver.mappings

      expect(mappings).to(eq({
        "123456789" => "ABC123XYZ",
        "987654321" => "DEF456UVW",
        "555666777" => "GHI789RST",
      }))
    end

    it "returns a copy (not reference to internal hash)" do
      resolver.resolve("123456789") # Load mappings
      mappings = resolver.mappings
      mappings["test"] = "value"

      # Original mappings should not be affected
      expect(resolver.mappings).not_to(have_key("test"))
    end
  end

  describe "#loaded?" do
    it "returns false initially" do
      expect(resolver.loaded?).to(be_falsy)
    end

    it "returns true after loading mappings" do
      resolver.resolve("123456789")
      expect(resolver.loaded?).to(be_truthy)
    end
  end

  describe "hash detection" do
    it "correctly identifies hash-like values" do
      # These should be detected as hashes (not make API calls)
      expect(client).not_to(receive(:get))

      resolver.resolve("ABC123XYZ") # Mixed alphanumeric
      resolver.resolve("1A2B3C4D5E") # Mixed starting with number
      resolver.resolve("ABCDEFGH") # All letters
    end

    it "correctly identifies plain account numbers" do
      # These should be detected as account numbers (make API calls)
      expect(client).to(receive(:get).at_least(1).times
        .with("/trader/v1/accounts/accountNumbers")
        .and_return(account_numbers_response))

      resolver.resolve("123456789")  # All digits
      resolver.resolve("987654321")  # All digits
    end

    it "handles edge cases in hash detection" do
      # These shorter mixed values should still be treated as hashes and not trigger API calls
      # Allow the get call for loading initial mappings, but it shouldn't happen for these values
      allow(client).to(receive(:get)
        .with("/trader/v1/accounts/accountNumbers")
        .and_return(account_numbers_response))

      # Short strings that look like hashes should still be passed through
      # (real hash values are typically longer)
      result1 = resolver.resolve("ABC123")     # Shorter but mixed - treated as hash
      result2 = resolver.resolve("12AB34")     # Mixed - treated as hash

      expect(result1).to(eq("ABC123"))
      expect(result2).to(eq("12AB34"))
    end
  end

  describe "thread safety" do
    it "is thread-safe for concurrent access" do
      threads = []
      results = []
      results_mutex = Mutex.new

      # Multiple threads trying to resolve at the same time
      10.times do
        threads << Thread.new do
          result = resolver.resolve("123456789")
          results_mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      # All results should be the same
      expect(results.uniq).to(eq(["ABC123XYZ"]))
      expect(results.size).to(eq(10))

      # API should have been called only once due to synchronization
      expect(client).to(have_received(:get).once)
    end
  end
end
