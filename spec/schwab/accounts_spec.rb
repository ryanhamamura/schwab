# frozen_string_literal: true

require "spec_helper"
require "schwab/accounts"

RSpec.describe(Schwab::Accounts) do
  let(:client) { instance_double("Schwab::Client") }
  let(:account_number) { "123456789" }

  before do
    allow(Schwab).to(receive(:client).and_return(client))
  end

  describe ".get_accounts" do
    let(:accounts_response) do
      {
        accounts: [
          { accountNumber: "123456789", type: "MARGIN" },
          { accountNumber: "987654321", type: "CASH" },
        ],
      }
    end

    it "fetches all accounts" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts", {}, Schwab::Resources::Account)
        .and_return(accounts_response))

      result = described_class.get_accounts
      expect(result).to(eq(accounts_response[:accounts]))
    end

    it "includes fields when specified" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts", { fields: "positions,orders" }, Schwab::Resources::Account)
        .and_return(accounts_response))

      described_class.get_accounts(fields: ["positions", "orders"])
    end

    it "uses provided client" do
      custom_client = instance_double("Schwab::Client")
      expect(custom_client).to(receive(:get)
        .with("/trader/v1/accounts", {}, Schwab::Resources::Account)
        .and_return(accounts_response))

      described_class.get_accounts(client: custom_client)
    end

    it "has list_accounts alias" do
      expect(described_class).to(respond_to(:list_accounts))
    end
  end

  describe ".get_account" do
    let(:account_response) do
      { accountNumber: account_number, type: "MARGIN", status: "ACTIVE" }
    end

    it "fetches a single account" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}", {}, Schwab::Resources::Account)
        .and_return(account_response))

      result = described_class.get_account(account_number)
      expect(result).to(eq(account_response))
    end

    it "includes fields when specified" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}", { fields: "positions" }, Schwab::Resources::Account)
        .and_return(account_response))

      described_class.get_account(account_number, fields: "positions")
    end

    it "encodes account number" do
      special_account = "123#456"
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/123%23456", {}, Schwab::Resources::Account)
        .and_return(account_response))

      described_class.get_account(special_account)
    end
  end

  describe ".get_positions" do
    let(:positions_response) do
      [
        { symbol: "AAPL", longQuantity: 100 },
        { symbol: "GOOGL", longQuantity: 50 },
      ]
    end

    it "fetches all positions for an account" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/positions", {}, Schwab::Resources::Position)
        .and_return(positions_response))

      result = described_class.get_positions(account_number)
      expect(result).to(eq(positions_response))
    end
  end

  describe ".get_position" do
    let(:symbol) { "AAPL" }
    let(:position_response) { { symbol: symbol, longQuantity: 100 } }

    it "fetches a specific position" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/positions/#{symbol}", {}, Schwab::Resources::Position)
        .and_return(position_response))

      result = described_class.get_position(account_number, symbol)
      expect(result).to(eq(position_response))
    end

    it "uppercases and encodes symbol" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/positions/BRK.B", {}, Schwab::Resources::Position)
        .and_return(position_response))

      described_class.get_position(account_number, "brk.b")
    end
  end

  describe ".get_transactions" do
    let(:transactions_response) do
      [
        { transactionId: "1", type: "TRADE", symbol: "AAPL" },
        { transactionId: "2", type: "DIVIDEND", symbol: "MSFT" },
      ]
    end

    it "fetches transactions for an account" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/transactions", {}, Schwab::Resources::Transaction)
        .and_return(transactions_response))

      result = described_class.get_transactions(account_number)
      expect(result).to(eq(transactions_response))
    end

    it "applies filters when specified" do
      start_date = Date.new(2024, 1, 1)
      end_date = Date.new(2024, 1, 31)

      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{account_number}/transactions",
          {
            types: "TRADE",
            startDate: "2024-01-01",
            endDate: "2024-01-31",
            symbol: "AAPL",
          },
          Schwab::Resources::Transaction,
        )
        .and_return(transactions_response))

      described_class.get_transactions(
        account_number,
        types: "TRADE",
        start_date: start_date,
        end_date: end_date,
        symbol: "AAPL",
      )
    end

    it "handles array of transaction types" do
      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{account_number}/transactions",
          { types: "TRADE,DIVIDEND" },
          Schwab::Resources::Transaction,
        )
        .and_return(transactions_response))

      described_class.get_transactions(account_number, types: ["TRADE", "DIVIDEND"])
    end
  end

  describe ".get_transaction" do
    let(:transaction_id) { "trans123" }
    let(:transaction_response) { { transactionId: transaction_id, type: "TRADE" } }

    it "fetches a specific transaction" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/transactions/#{transaction_id}", {}, Schwab::Resources::Transaction)
        .and_return(transaction_response))

      result = described_class.get_transaction(account_number, transaction_id)
      expect(result).to(eq(transaction_response))
    end
  end

  describe ".get_orders" do
    let(:orders_response) do
      [
        { orderId: "1", status: "FILLED" },
        { orderId: "2", status: "WORKING" },
      ]
    end

    it "fetches orders for an account" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/orders", {}, Schwab::Resources::Order)
        .and_return(orders_response))

      result = described_class.get_orders(account_number)
      expect(result).to(eq(orders_response))
    end

    it "applies filters when specified" do
      from_time = Time.new(2024, 1, 1, 9, 30, 0)
      to_time = Time.new(2024, 1, 31, 16, 0, 0)

      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{account_number}/orders",
          {
            fromEnteredTime: from_time.iso8601,
            toEnteredTime: to_time.iso8601,
            status: "FILLED",
            maxResults: 100,
          },
          Schwab::Resources::Order,
        )
        .and_return(orders_response))

      described_class.get_orders(
        account_number,
        from_entered_time: from_time,
        to_entered_time: to_time,
        status: "FILLED",
        max_results: 100,
      )
    end
  end

  describe ".get_all_orders" do
    let(:orders_response) do
      [
        { orderId: "1", accountNumber: "123456789" },
        { orderId: "2", accountNumber: "987654321" },
      ]
    end

    it "fetches orders for all accounts" do
      expect(client).to(receive(:get)
        .with("/trader/v1/orders", {}, Schwab::Resources::Order)
        .and_return(orders_response))

      result = described_class.get_all_orders
      expect(result).to(eq(orders_response))
    end

    it "applies filters when specified" do
      expect(client).to(receive(:get)
        .with(
          "/trader/v1/orders",
          { status: "WORKING,PENDING_ACTIVATION" },
          Schwab::Resources::Order,
        )
        .and_return(orders_response))

      described_class.get_all_orders(status: ["WORKING", "PENDING_ACTIVATION"])
    end
  end

  describe ".get_order" do
    let(:order_id) { "order123" }
    let(:order_response) { { orderId: order_id, status: "FILLED" } }

    it "fetches a specific order" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/orders/#{order_id}", {}, Schwab::Resources::Order)
        .and_return(order_response))

      result = described_class.get_order(account_number, order_id)
      expect(result).to(eq(order_response))
    end
  end

  describe ".get_preferences" do
    let(:preferences_response) do
      { expressTrading: true, defaultEquityOrderType: "LIMIT" }
    end

    it "fetches account preferences" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{account_number}/preferences")
        .and_return(preferences_response))

      result = described_class.get_preferences(account_number)
      expect(result).to(eq(preferences_response))
    end
  end

  describe ".update_preferences" do
    let(:preferences) { { expressTrading: false } }
    let(:updated_response) { preferences }

    it "updates account preferences" do
      expect(client).to(receive(:put)
        .with("/trader/v1/accounts/#{account_number}/preferences", preferences)
        .and_return(updated_response))

      result = described_class.update_preferences(account_number, preferences)
      expect(result).to(eq(updated_response))
    end
  end

  describe ".get_user_preferences" do
    let(:user_preferences_response) do
      { streamerInfo: {}, offers: {} }
    end

    it "fetches user preferences" do
      expect(client).to(receive(:get)
        .with("/trader/v1/userPreference")
        .and_return(user_preferences_response))

      result = described_class.get_user_preferences
      expect(result).to(eq(user_preferences_response))
    end
  end

  describe "error handling" do
    it "raises error when no client is configured" do
      allow(Schwab).to(receive(:client).and_return(nil))

      expect { described_class.get_accounts }.to(raise_error(
        Schwab::Error,
        "No client configured. Set Schwab.client or pass a client instance.",
      ))
    end
  end

  describe "date/time formatting" do
    it "formats Date objects correctly" do
      date = Date.new(2024, 1, 15)
      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{account_number}/transactions",
          { startDate: "2024-01-15" },
          Schwab::Resources::Transaction,
        )
        .and_return([]))

      described_class.get_transactions(account_number, start_date: date)
    end

    it "formats Time objects correctly" do
      time = Time.new(2024, 1, 15, 10, 30, 0)
      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{account_number}/orders",
          { fromEnteredTime: time.iso8601 },
          Schwab::Resources::Order,
        )
        .and_return([]))

      described_class.get_orders(account_number, from_entered_time: time)
    end

    it "parses date strings" do
      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{account_number}/transactions",
          { startDate: "2024-01-15" },
          Schwab::Resources::Transaction,
        )
        .and_return([]))

      described_class.get_transactions(account_number, start_date: "2024-01-15")
    end
  end
end
