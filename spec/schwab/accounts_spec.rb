# frozen_string_literal: true

require "spec_helper"
require "schwab/accounts"

RSpec.describe(Schwab::Accounts) do
  let(:client) { instance_double("Schwab::Client") }
  let(:account_number) { "123456789" }
  let(:encrypted_account) { "ABC123XYZ" }

  before do
    allow(Schwab).to(receive(:client).and_return(client))
    # Mock the account resolver to return encrypted values
    allow(client).to(receive(:resolve_account_number)
      .with(account_number)
      .and_return(encrypted_account))
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
        .with("/trader/v1/accounts/#{encrypted_account}", {}, Schwab::Resources::Account)
        .and_return(account_response))

      result = described_class.get_account(account_number)
      expect(result).to(eq(account_response))
    end

    it "includes fields when specified" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/#{encrypted_account}", { fields: "positions" }, Schwab::Resources::Account)
        .and_return(account_response))

      described_class.get_account(account_number, fields: "positions")
    end

    it "encodes account number" do
      special_account = "123#456"
      expect(client).to(receive(:resolve_account_number)
        .with(special_account)
        .and_return("ENCODED123HASH"))
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/ENCODED123HASH", {}, Schwab::Resources::Account)
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

    let(:account_with_positions) do
      {
        accountNumber: account_number,
        securitiesAccount: {
          positions: positions_response,
        },
      }
    end

    it "fetches positions by calling get_account with positions field" do
      expect(described_class).to(receive(:get_account)
        .with(account_number, { fields: "positions", client: client })
        .and_return(account_with_positions))

      result = described_class.get_positions(account_number, client: client)
      expect(result).to(eq(positions_response))
    end

    it "returns empty array when no positions" do
      account_no_positions = { accountNumber: account_number }
      expect(described_class).to(receive(:get_account)
        .with(account_number, { fields: "positions", client: client })
        .and_return(account_no_positions))

      result = described_class.get_positions(account_number, client: client)
      expect(result).to(eq([]))
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
        .with("/trader/v1/accounts/#{encrypted_account}/transactions", {}, Schwab::Resources::Transaction)
        .and_return(transactions_response))

      result = described_class.get_transactions(account_number)
      expect(result).to(eq(transactions_response))
    end

    it "applies filters when specified" do
      start_date = Date.new(2024, 1, 1)
      end_date = Date.new(2024, 1, 31)

      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{encrypted_account}/transactions",
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
          "/trader/v1/accounts/#{encrypted_account}/transactions",
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
        .with("/trader/v1/accounts/#{encrypted_account}/transactions/#{transaction_id}", {}, Schwab::Resources::Transaction)
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
        .with("/trader/v1/accounts/#{encrypted_account}/orders", {}, Schwab::Resources::Order)
        .and_return(orders_response))

      result = described_class.get_orders(account_number)
      expect(result).to(eq(orders_response))
    end

    it "applies filters when specified" do
      from_time = Time.new(2024, 1, 1, 9, 30, 0)
      to_time = Time.new(2024, 1, 31, 16, 0, 0)

      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{encrypted_account}/orders",
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
        .with("/trader/v1/accounts/#{encrypted_account}/orders/#{order_id}", {}, Schwab::Resources::Order)
        .and_return(order_response))

      result = described_class.get_order(account_number, order_id)
      expect(result).to(eq(order_response))
    end
  end

  describe ".preview_order" do
    let(:order_data) do
      {
        orderType: "MARKET",
        session: "NORMAL",
        duration: "DAY",
        orderStrategyType: "SINGLE",
        orderLegCollection: [{
          instruction: "BUY",
          quantity: 10,
          instrument: {
            symbol: "AAPL",
            assetType: "EQUITY",
          },
        }],
      }
    end

    let(:preview_response) do
      {
        orderActivity: {
          activityType: "EXECUTION",
          executionType: "FILL",
          quantity: 10,
          orderRemainingQuantity: 0,
          executionLegs: [{
            legId: 1,
            quantity: 10,
            mismarkedQuantity: 0,
            price: 150.25,
            time: "2024-01-15T14:30:00Z",
          }],
        },
        previewId: "preview123",
        orderValue: {
          commission: 0,
          fees: {
            additionalFee: 0,
            commission: 0,
            optRegFee: 0,
            otherCharges: 0,
            rFee: 0,
            secFee: 0.01,
          },
        },
      }
    end

    it "previews an order" do
      expect(client).to(receive(:post)
        .with("/trader/v1/accounts/#{encrypted_account}/previewOrder", order_data)
        .and_return(preview_response))

      result = described_class.preview_order(account_number, order_data)
      expect(result).to(eq(preview_response))
    end
  end

  describe ".get_account_numbers" do
    let(:account_numbers_response) do
      [
        { accountNumber: "123456789", hashValue: "ABC123XYZ" },
        { accountNumber: "987654321", hashValue: "DEF456UVW" },
      ]
    end

    it "fetches account numbers and hash values" do
      expect(client).to(receive(:get)
        .with("/trader/v1/accounts/accountNumbers")
        .and_return(account_numbers_response))

      result = described_class.get_account_numbers
      expect(result).to(eq(account_numbers_response))
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
          "/trader/v1/accounts/#{encrypted_account}/transactions",
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
          "/trader/v1/accounts/#{encrypted_account}/orders",
          { fromEnteredTime: time.iso8601 },
          Schwab::Resources::Order,
        )
        .and_return([]))

      described_class.get_orders(account_number, from_entered_time: time)
    end

    it "parses date strings" do
      expect(client).to(receive(:get)
        .with(
          "/trader/v1/accounts/#{encrypted_account}/transactions",
          { startDate: "2024-01-15" },
          Schwab::Resources::Transaction,
        )
        .and_return([]))

      described_class.get_transactions(account_number, start_date: "2024-01-15")
    end
  end
end
