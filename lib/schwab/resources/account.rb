# frozen_string_literal: true

require_relative "base"

module Schwab
  module Resources
    # Resource wrapper for account objects
    # Provides account-specific helper methods and type coercions
    class Account < Base
      # Set up field type coercions for account fields
      set_field_type :created_time, :datetime
      set_field_type :opened_date, :date
      set_field_type :closed_date, :date
      set_field_type :last_updated, :datetime
      set_field_type :day_trader, :boolean
      set_field_type :closing_only_restricted, :boolean
      set_field_type :pdt_flag, :boolean
      set_field_type :round_trips, :integer

      # Get the account number/ID (plain text)
      #
      # @return [String] The account number
      def account_number
        self[:accountNumber] || self[:account_number]
      end
      alias_method :id, :account_number

      # Get the encrypted hash value for this account
      #
      # @return [String, nil] The encrypted hash value used in API calls
      def hash_value
        self[:hashValue] || self[:hash_value]
      end
      alias_method :encrypted_id, :hash_value

      # Get the appropriate account identifier for API calls
      # Returns hash_value if available, otherwise account_number
      #
      # @return [String] The account identifier to use in API calls
      def api_identifier
        hash_value || account_number
      end

      # Get the account type
      #
      # @return [String] The account type (e.g., "CASH", "MARGIN")
      def account_type
        self[:type] || self[:accountType] || self[:account_type]
      end

      # Check if this is a margin account
      #
      # @return [Boolean] True if margin account
      def margin_account?
        account_type == "MARGIN"
      end

      # Check if this is a cash account
      #
      # @return [Boolean] True if cash account
      def cash_account?
        account_type == "CASH"
      end

      # Get account status
      #
      # @return [String] The account status
      def status
        self[:status] || self[:accountStatus]
      end

      # Check if account is active
      #
      # @return [Boolean] True if account is active
      def active?
        status == "ACTIVE"
      end

      # Get the current balances
      #
      # @return [Schwab::Resources::Base] The current balances object
      def current_balances
        self[:currentBalances] || self[:current_balances]
      end

      # Get the initial balances
      #
      # @return [Schwab::Resources::Base] The initial balances object
      def initial_balances
        self[:initialBalances] || self[:initial_balances]
      end

      # Get projected balances
      #
      # @return [Schwab::Resources::Base] The projected balances object
      def projected_balances
        self[:projectedBalances] || self[:projected_balances]
      end

      # Get positions
      #
      # @return [Array<Schwab::Resources::Position>] Array of positions
      def positions
        positions_data = self[:positions] || []
        positions_data.map do |position_data|
          if position_data.is_a?(Position)
            position_data
          else
            Position.new(position_data, client)
          end
        end
      end

      # Get account value (net liquidation value)
      #
      # @return [Float, nil] The total account value
      def account_value
        return unless current_balances

        current_balances[:liquidationValue] ||
          current_balances[:liquidation_value] ||
          current_balances[:totalValue] ||
          current_balances[:total_value]
      end
      alias_method :net_liquidation_value, :account_value
      alias_method :total_value, :account_value

      # Get cash balance
      #
      # @return [Float, nil] The cash balance
      def cash_balance
        return unless current_balances

        current_balances[:cashBalance] ||
          current_balances[:cash_balance] ||
          current_balances[:availableFunds] ||
          current_balances[:available_funds]
      end

      # Get buying power
      #
      # @return [Float, nil] The buying power
      def buying_power
        return unless current_balances

        current_balances[:buyingPower] ||
          current_balances[:buying_power] ||
          current_balances[:availableFundsTrade] ||
          current_balances[:available_funds_trade]
      end

      # Get day trading buying power
      #
      # @return [Float, nil] The day trading buying power
      def day_trading_buying_power
        return unless current_balances

        current_balances[:dayTradingBuyingPower] ||
          current_balances[:day_trading_buying_power]
      end

      # Get maintenance requirement
      #
      # @return [Float, nil] The maintenance requirement
      def maintenance_requirement
        return unless current_balances

        current_balances[:maintenanceRequirement] ||
          current_balances[:maintenance_requirement] ||
          current_balances[:maintReq] ||
          current_balances[:maint_req]
      end

      # Get margin balance if applicable
      #
      # @return [Float, nil] The margin balance
      def margin_balance
        return unless margin_account? && current_balances

        current_balances[:marginBalance] ||
          current_balances[:margin_balance]
      end

      # Check if account is in margin call
      #
      # @return [Boolean, nil] True if in margin call
      def margin_call?
        return false unless margin_account? && current_balances

        in_call = current_balances[:isInCall] ||
          current_balances[:is_in_call] ||
          current_balances[:inCall] ||
          current_balances[:in_call]

        !!in_call
      end

      # Get account equity
      #
      # @return [Float, nil] The account equity
      def equity
        return unless current_balances

        current_balances[:equity] ||
          current_balances[:accountEquity] ||
          current_balances[:account_equity]
      end

      # Calculate total P&L for all positions
      #
      # @return [Float] Total profit/loss
      def total_pnl
        positions.sum { |position| position.unrealized_pnl || 0 }
      end

      # Calculate today's P&L for all positions
      #
      # @return [Float] Today's profit/loss
      def todays_pnl
        positions.sum { |position| position.day_pnl || 0 }
      end

      # Get positions filtered by asset type
      #
      # @param asset_type [String, Symbol] The asset type (e.g., :equity, :option)
      # @return [Array<Schwab::Resources::Position>] Filtered positions
      def positions_by_type(asset_type)
        type_str = asset_type.to_s.upcase
        positions.select do |position|
          position.asset_type == type_str ||
            position[:assetType] == type_str ||
            position[:asset_type] == type_str
        end
      end

      # Get equity positions
      #
      # @return [Array<Schwab::Resources::Position>] Equity positions
      def equity_positions
        positions_by_type(:equity)
      end

      # Get option positions
      #
      # @return [Array<Schwab::Resources::Position>] Option positions
      def option_positions
        positions_by_type(:option)
      end

      # Calculate total market value of positions
      #
      # @return [Float] Total market value
      def total_market_value
        positions.sum { |position| position.market_value || 0 }
      end

      # Check if account has positions
      #
      # @return [Boolean] True if account has positions
      def has_positions?
        !positions.empty?
      end

      # Get number of positions
      #
      # @return [Integer] Number of positions
      def position_count
        positions.size
      end
    end
  end
end
