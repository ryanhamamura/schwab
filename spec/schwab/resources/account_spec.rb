# frozen_string_literal: true

require "spec_helper"
require "schwab/resources/account"
require "schwab/resources/position"

RSpec.describe(Schwab::Resources::Account) do
  let(:client) { double("Schwab::Client") }

  describe "account identification" do
    it "retrieves account number from various keys" do
      account = described_class.new({ accountNumber: "123456" })
      expect(account.account_number).to(eq("123456"))
      expect(account.id).to(eq("123456"))

      account = described_class.new({ account_number: "789012" })
      expect(account.account_number).to(eq("789012"))
    end

    it "retrieves account type" do
      account = described_class.new({ type: "MARGIN" })
      expect(account.account_type).to(eq("MARGIN"))

      account = described_class.new({ accountType: "CASH" })
      expect(account.account_type).to(eq("CASH"))
    end
  end

  describe "account type checks" do
    it "identifies margin accounts" do
      account = described_class.new({ type: "MARGIN" })
      expect(account.margin_account?).to(be(true))
      expect(account.cash_account?).to(be(false))
    end

    it "identifies cash accounts" do
      account = described_class.new({ type: "CASH" })
      expect(account.cash_account?).to(be(true))
      expect(account.margin_account?).to(be(false))
    end
  end

  describe "status checks" do
    it "retrieves account status" do
      account = described_class.new({ status: "ACTIVE" })
      expect(account.status).to(eq("ACTIVE"))
    end

    it "checks if account is active" do
      account = described_class.new({ status: "ACTIVE" })
      expect(account.active?).to(be(true))

      account = described_class.new({ status: "CLOSED" })
      expect(account.active?).to(be(false))
    end
  end

  describe "balances" do
    let(:balances_data) do
      {
        liquidationValue: 50000.00,
        cashBalance: 10000.00,
        buyingPower: 20000.00,
        dayTradingBuyingPower: 40000.00,
        maintenanceRequirement: 5000.00,
        equity: 45000.00,
      }
    end

    let(:account) do
      described_class.new({ currentBalances: balances_data })
    end

    it "retrieves current balances object" do
      expect(account.current_balances).to(be_a(Schwab::Resources::Base))
      expect(account.current_balances[:liquidationValue]).to(eq(50000.00))
    end

    it "retrieves account value" do
      expect(account.account_value).to(eq(50000.00))
      expect(account.net_liquidation_value).to(eq(50000.00))
      expect(account.total_value).to(eq(50000.00))
    end

    it "retrieves cash balance" do
      expect(account.cash_balance).to(eq(10000.00))
    end

    it "retrieves buying power" do
      expect(account.buying_power).to(eq(20000.00))
    end

    it "retrieves day trading buying power" do
      expect(account.day_trading_buying_power).to(eq(40000.00))
    end

    it "retrieves maintenance requirement" do
      expect(account.maintenance_requirement).to(eq(5000.00))
    end

    it "retrieves equity" do
      expect(account.equity).to(eq(45000.00))
    end

    it "returns nil when balances not present" do
      account = described_class.new({})
      expect(account.account_value).to(be_nil)
      expect(account.cash_balance).to(be_nil)
      expect(account.buying_power).to(be_nil)
    end
  end

  describe "margin account features" do
    let(:margin_account) do
      described_class.new({
        type: "MARGIN",
        currentBalances: {
          marginBalance: 15000.00,
          isInCall: true,
        },
      })
    end

    it "retrieves margin balance for margin accounts" do
      expect(margin_account.margin_balance).to(eq(15000.00))
    end

    it "checks margin call status" do
      expect(margin_account.margin_call?).to(be(true))
    end

    it "returns nil for margin features on cash accounts" do
      cash_account = described_class.new({ type: "CASH" })
      expect(cash_account.margin_balance).to(be_nil)
      expect(cash_account.margin_call?).to(be(false))
    end
  end

  describe "positions" do
    let(:positions_data) do
      [
        {
          instrument: { symbol: "AAPL", assetType: "EQUITY" },
          longQuantity: 100,
          averagePrice: 150.00,
        },
        {
          instrument: { symbol: "GOOGL", assetType: "EQUITY" },
          longQuantity: 50,
          averagePrice: 2500.00,
        },
      ]
    end

    let(:account) do
      described_class.new({ positions: positions_data }, client)
    end

    it "returns array of Position objects" do
      positions = account.positions
      expect(positions).to(be_an(Array))
      expect(positions.size).to(eq(2))
      expect(positions.first).to(be_a(Schwab::Resources::Position))
    end

    it "wraps position data correctly" do
      position = account.positions.first
      expect(position.symbol).to(eq("AAPL"))
      expect(position.quantity).to(eq(100))
    end

    it "filters positions by asset type" do
      equity_positions = account.positions_by_type(:equity)
      expect(equity_positions.size).to(eq(2))

      option_positions = account.positions_by_type(:option)
      expect(option_positions).to(be_empty)
    end

    it "provides convenience methods for equity and option positions" do
      expect(account.equity_positions.size).to(eq(2))
      expect(account.option_positions).to(be_empty)
    end

    it "calculates total P&L across positions" do
      allow_any_instance_of(Schwab::Resources::Position).to(receive(:unrealized_pnl).and_return(500.00))
      expect(account.total_pnl).to(eq(1000.00))
    end

    it "calculates today's P&L across positions" do
      allow_any_instance_of(Schwab::Resources::Position).to(receive(:day_pnl).and_return(100.00))
      expect(account.todays_pnl).to(eq(200.00))
    end

    it "calculates total market value" do
      allow_any_instance_of(Schwab::Resources::Position).to(receive(:market_value).and_return(1000.00))
      expect(account.total_market_value).to(eq(2000.00))
    end

    it "checks if account has positions" do
      expect(account.has_positions?).to(be(true))

      empty_account = described_class.new({})
      expect(empty_account.has_positions?).to(be(false))
    end

    it "returns position count" do
      expect(account.position_count).to(eq(2))
    end
  end

  describe "type coercion" do
    it "coerces date/time fields" do
      account = described_class.new({
        created_time: "2024-01-15T10:30:00Z",
        opened_date: "2024-01-01",
        last_updated: "2024-01-15T15:45:00Z",
      })

      # DateTime/Time coercion can return either type
      expect(account.created_time).to(satisfy { |v| v.is_a?(DateTime) || v.is_a?(Time) })
      expect(account.opened_date).to(be_a(Date))
      expect(account.last_updated).to(satisfy { |v| v.is_a?(DateTime) || v.is_a?(Time) })
    end

    it "coerces boolean fields" do
      account = described_class.new({
        day_trader: "true",
        closing_only_restricted: 0,
        pdt_flag: 1,
      })

      expect(account.day_trader).to(be(true))
      expect(account.closing_only_restricted).to(be(false))
      expect(account.pdt_flag).to(be(true))
    end

    it "coerces integer fields" do
      account = described_class.new({
        round_trips: "3",
      })

      expect(account.round_trips).to(eq(3))
      expect(account.round_trips).to(be_a(Integer))
    end
  end

  describe "encrypted account number support" do
    let(:account_data_with_hash) do
      {
        accountNumber: "123456789",
        hashValue: "ABC123XYZ",
        type: "MARGIN",
        status: "ACTIVE",
      }
    end

    describe "#hash_value" do
      it "returns the hash value when present" do
        account = described_class.new(account_data_with_hash, client)
        expect(account.hash_value).to(eq("ABC123XYZ"))
      end

      it "supports snake_case key" do
        data = { accountNumber: "123456789", hash_value: "DEF456UVW" }
        account = described_class.new(data, client)
        expect(account.hash_value).to(eq("DEF456UVW"))
      end

      it "returns nil when not present" do
        account = described_class.new({ accountNumber: "123456789" }, client)
        expect(account.hash_value).to(be_nil)
      end
    end

    describe "#encrypted_id" do
      it "is an alias for hash_value" do
        account = described_class.new(account_data_with_hash, client)
        expect(account.encrypted_id).to(eq("ABC123XYZ"))
      end
    end

    describe "#api_identifier" do
      it "returns hash_value when present" do
        account = described_class.new(account_data_with_hash, client)
        expect(account.api_identifier).to(eq("ABC123XYZ"))
      end

      it "falls back to account_number when hash_value not present" do
        account = described_class.new({ accountNumber: "123456789" }, client)
        expect(account.api_identifier).to(eq("123456789"))
      end
    end
  end
end
