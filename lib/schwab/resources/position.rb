# frozen_string_literal: true

require_relative "base"

module Schwab
  module Resources
    # Resource wrapper for position objects
    # Provides position-specific calculations and helper methods
    class Position < Base
      # Set up field type coercions for position fields
      set_field_type :average_price, :float
      set_field_type :current_day_cost, :float
      set_field_type :current_day_profit_loss, :float
      set_field_type :current_day_profit_loss_percentage, :float
      set_field_type :long_quantity, :float
      set_field_type :short_quantity, :float
      set_field_type :settled_long_quantity, :float
      set_field_type :settled_short_quantity, :float
      set_field_type :market_value, :float
      set_field_type :maintenance_requirement, :float
      set_field_type :previous_session_long_quantity, :float
      set_field_type :previous_session_short_quantity, :float

      # Get the symbol
      #
      # @return [String] The position symbol
      def symbol
        if self[:instrument]
          self[:instrument][:symbol] || self[:instrument][:underlying_symbol]
        else
          self[:symbol]
        end
      end

      # Get the asset type
      #
      # @return [String] The asset type (e.g., "EQUITY", "OPTION")
      def asset_type
        if self[:instrument]
          self[:instrument][:assetType] || self[:instrument][:asset_type]
        else
          self[:assetType] || self[:asset_type]
        end
      end

      # Get the CUSIP
      #
      # @return [String] The CUSIP identifier
      def cusip
        if self[:instrument]
          self[:instrument][:cusip]
        else
          self[:cusip]
        end
      end

      # Get the quantity (net of long and short)
      #
      # @return [Float] The net quantity
      def quantity
        long_qty = (self[:longQuantity] || self[:long_quantity] || 0).to_f
        short_qty = (self[:shortQuantity] || self[:short_quantity] || 0).to_f
        long_qty - short_qty
      end
      alias_method :net_quantity, :quantity

      # Get the average price (cost basis per share)
      #
      # @return [Float, nil] The average price
      def average_price
        self[:averagePrice] || self[:average_price]
      end
      alias_method :cost_basis_per_share, :average_price

      # Get the current price
      #
      # @return [Float, nil] The current market price
      def current_price
        if self[:instrument] && self[:instrument][:lastPrice]
          self[:instrument][:lastPrice]
        elsif self[:quote]
          self[:quote][:last] || self[:quote][:mark]
        else
          self[:currentPrice] || self[:current_price] || self[:lastPrice] || self[:last_price]
        end
      end
      alias_method :market_price, :current_price
      alias_method :last_price, :current_price

      # Get the market value of the position
      #
      # @return [Float] The market value
      def market_value
        value = self[:marketValue] || self[:market_value]
        return value.to_f if value

        # Calculate if not provided
        if current_price && quantity
          (current_price * quantity.abs).round(2)
        else
          0.0
        end
      end

      # Calculate the total cost basis
      #
      # @return [Float] The total cost basis
      def cost_basis
        if average_price && quantity
          (average_price * quantity.abs).round(2)
        else
          0.0
        end
      end
      alias_method :total_cost, :cost_basis

      # Calculate unrealized P&L
      #
      # @return [Float] The unrealized profit/loss
      def unrealized_pnl
        market_value - cost_basis
      end
      alias_method :unrealized_profit_loss, :unrealized_pnl

      # Calculate unrealized P&L percentage
      #
      # @return [Float, nil] The unrealized profit/loss percentage
      def unrealized_pnl_percentage
        return if cost_basis.zero?

        ((unrealized_pnl / cost_basis) * 100).round(2)
      end
      alias_method :unrealized_profit_loss_percentage, :unrealized_pnl_percentage

      # Get today's P&L
      #
      # @return [Float, nil] Today's profit/loss
      def day_pnl
        self[:currentDayProfitLoss] ||
          self[:current_day_profit_loss] ||
          self[:dayProfitLoss] ||
          self[:day_profit_loss]
      end
      alias_method :todays_pnl, :day_pnl
      alias_method :current_day_pnl, :day_pnl

      # Get today's P&L percentage
      #
      # @return [Float, nil] Today's profit/loss percentage
      def day_pnl_percentage
        self[:currentDayProfitLossPercentage] ||
          self[:current_day_profit_loss_percentage] ||
          self[:dayProfitLossPercentage] ||
          self[:day_profit_loss_percentage]
      end
      alias_method :todays_pnl_percentage, :day_pnl_percentage
      alias_method :current_day_pnl_percentage, :day_pnl_percentage

      # Check if this is a long position
      #
      # @return [Boolean] True if long position
      def long?
        quantity > 0
      end

      # Check if this is a short position
      #
      # @return [Boolean] True if short position
      def short?
        quantity < 0
      end

      # Check if this is an equity position
      #
      # @return [Boolean] True if equity
      def equity?
        asset_type == "EQUITY"
      end

      # Check if this is an option position
      #
      # @return [Boolean] True if option
      def option?
        asset_type == "OPTION"
      end

      # Check if this is a profitable position
      #
      # @return [Boolean] True if profitable
      def profitable?
        unrealized_pnl > 0
      end

      # Check if this is a losing position
      #
      # @return [Boolean] True if losing
      def losing?
        unrealized_pnl < 0
      end

      # Get maintenance requirement for this position
      #
      # @return [Float, nil] The maintenance requirement
      def maintenance_requirement
        self[:maintenanceRequirement] || self[:maintenance_requirement]
      end

      # Get the instrument details
      #
      # @return [Hash, nil] The instrument details
      def instrument
        self[:instrument]
      end

      # Get option details if this is an option position
      #
      # @return [Hash, nil] Option details including strike, expiration, etc.
      def option_details
        return unless option? && instrument

        {
          underlying_symbol: instrument[:underlyingSymbol] || instrument[:underlying_symbol],
          strike_price: instrument[:strikePrice] || instrument[:strike_price],
          expiration_date: instrument[:expirationDate] || instrument[:expiration_date],
          option_type: instrument[:putCall] || instrument[:put_call] || instrument[:optionType] || instrument[:option_type],
          contract_size: instrument[:contractSize] || instrument[:contract_size] || 100,
        }
      end

      # Get the underlying symbol for options
      #
      # @return [String, nil] The underlying symbol
      def underlying_symbol
        return unless option?

        option_details[:underlying_symbol] if option_details
      end

      # Get the strike price for options
      #
      # @return [Float, nil] The strike price
      def strike_price
        return unless option?

        option_details[:strike_price] if option_details
      end

      # Get the expiration date for options
      #
      # @return [String, nil] The expiration date
      def expiration_date
        return unless option?

        option_details[:expiration_date] if option_details
      end

      # Check if this is a call option
      #
      # @return [Boolean, nil] True if call option
      def call?
        return false unless option?

        details = option_details
        return false unless details

        details[:option_type] == "CALL" || details[:option_type] == "call"
      end

      # Check if this is a put option
      #
      # @return [Boolean, nil] True if put option
      def put?
        return false unless option?

        details = option_details
        return false unless details

        details[:option_type] == "PUT" || details[:option_type] == "put"
      end

      # Calculate the value per contract for options
      #
      # @return [Float, nil] Value per contract
      def value_per_contract
        return unless option? && market_value && quantity != 0

        contracts = quantity.abs
        market_value / contracts
      end

      # Calculate cost per contract for options
      #
      # @return [Float, nil] Cost per contract
      def cost_per_contract
        return unless option? && cost_basis != 0 && quantity != 0

        contracts = quantity.abs
        cost_basis / contracts
      end

      # Get formatted display string for the position
      #
      # @return [String] Formatted position string
      def to_display_string
        if option?
          details = option_details
          if details
            "#{quantity.to_i} #{details[:underlying_symbol]} #{details[:strike_price]} #{details[:option_type]} #{details[:expiration_date]}"
          else
            "#{quantity.to_i} #{symbol}"
          end
        else
          "#{quantity} shares of #{symbol}"
        end
      end
    end
  end
end
