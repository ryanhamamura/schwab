# frozen_string_literal: true

require_relative "base"

module Schwab
  module Resources
    # Resource wrapper for strategy objects (complex multi-leg orders)
    # Provides strategy-specific helper methods for options strategies
    class Strategy < Base
      # Set up field type coercions for strategy fields
      set_field_type :entered_time, :datetime
      set_field_type :close_time, :datetime
      set_field_type :filled_quantity, :float
      set_field_type :remaining_quantity, :float
      set_field_type :quantity, :float

      # Get strategy type
      #
      # @return [String] The strategy type
      def strategy_type
        self[:strategyType] || self[:strategy_type] || self[:type]
      end
      alias_method :type, :strategy_type

      # Get the strategy name/description
      #
      # @return [String] The strategy name
      def name
        self[:strategyName] || self[:strategy_name] || self[:name] || strategy_type
      end

      # Get strategy status
      #
      # @return [String] The strategy status
      def status
        self[:status] || self[:strategyStatus] || self[:strategy_status]
      end

      # Get the legs of the strategy
      #
      # @return [Array] Array of strategy legs
      def legs
        self[:legs] || self[:strategyLegs] || self[:strategy_legs] || self[:orderLegCollection] || []
      end

      # Get number of legs
      #
      # @return [Integer] Number of legs in strategy
      def leg_count
        legs.size
      end

      # Check if this is a single-leg strategy
      #
      # @return [Boolean] True if single leg
      def single_leg?
        leg_count == 1
      end

      # Check if this is a multi-leg strategy
      #
      # @return [Boolean] True if multi-leg
      def multi_leg?
        leg_count > 1
      end

      # Get the underlying symbol
      #
      # @return [String, nil] The underlying symbol
      def underlying_symbol
        # All legs should have the same underlying for a valid strategy
        first_leg = legs.first
        return unless first_leg

        if first_leg[:instrument]
          first_leg[:instrument][:underlyingSymbol] ||
            first_leg[:instrument][:underlying_symbol] ||
            first_leg[:instrument][:symbol]
        end
      end

      # Get all strike prices in the strategy
      #
      # @return [Array<Float>] Array of strike prices
      def strike_prices
        legs.map do |leg|
          if leg[:instrument]
            leg[:instrument][:strikePrice] || leg[:instrument][:strike_price]
          end
        end.compact.uniq.sort
      end

      # Get all expiration dates in the strategy
      #
      # @return [Array<String>] Array of expiration dates
      def expiration_dates
        legs.map do |leg|
          if leg[:instrument]
            leg[:instrument][:expirationDate] || leg[:instrument][:expiration_date]
          end
        end.compact.uniq.sort
      end

      # Get net credit/debit
      #
      # @return [Float, nil] Net credit (positive) or debit (negative)
      def net_premium
        total = 0.0
        legs.each do |leg|
          price = leg[:price] || 0
          quantity = leg[:quantity] || 0
          instruction = leg[:instruction]

          # Selling generates credit, buying generates debit
          if ["SELL", "SELL_TO_OPEN", "SELL_TO_CLOSE"].include?(instruction&.upcase)
            total += price * quantity * 100 # Options are in contracts of 100
          else
            total -= price * quantity * 100
          end
        end
        total
      end

      # Check if this is a credit strategy
      #
      # @return [Boolean] True if net credit
      def credit_strategy?
        net_premium > 0
      end

      # Check if this is a debit strategy
      #
      # @return [Boolean] True if net debit
      def debit_strategy?
        net_premium < 0
      end

      # Strategy type identification methods

      # Check if this is a vertical spread
      #
      # @return [Boolean] True if vertical spread
      def vertical_spread?
        return false unless leg_count == 2

        expirations = expiration_dates
        strikes = strike_prices

        # Same expiration, different strikes
        expirations.size == 1 && strikes.size == 2
      end
      alias_method :vertical?, :vertical_spread?

      # Check if this is a calendar spread
      #
      # @return [Boolean] True if calendar spread
      def calendar_spread?
        return false unless leg_count == 2

        expirations = expiration_dates
        strikes = strike_prices

        # Different expirations, same strike
        expirations.size == 2 && strikes.size == 1
      end
      alias_method :calendar?, :calendar_spread?
      alias_method :horizontal?, :calendar_spread?

      # Check if this is a diagonal spread
      #
      # @return [Boolean] True if diagonal spread
      def diagonal_spread?
        return false unless leg_count == 2

        expirations = expiration_dates
        strikes = strike_prices

        # Different expirations and strikes
        expirations.size == 2 && strikes.size == 2
      end
      alias_method :diagonal?, :diagonal_spread?

      # Check if this is a butterfly spread
      #
      # @return [Boolean] True if butterfly
      def butterfly?
        return false unless leg_count == 4

        strikes = strike_prices
        # Butterfly has 3 unique strikes
        strikes.size == 3
      end

      # Check if this is an iron butterfly
      #
      # @return [Boolean] True if iron butterfly
      def iron_butterfly?
        return false unless butterfly?

        # Iron butterfly uses both puts and calls
        has_puts = legs.any? { |leg| leg_is_put?(leg) }
        has_calls = legs.any? { |leg| leg_is_call?(leg) }

        has_puts && has_calls
      end

      # Check if this is a condor
      #
      # @return [Boolean] True if condor
      def condor?
        return false unless leg_count == 4

        strikes = strike_prices
        # Condor has 4 unique strikes
        strikes.size == 4
      end

      # Check if this is an iron condor
      #
      # @return [Boolean] True if iron condor
      def iron_condor?
        return false unless condor?

        # Iron condor uses both puts and calls
        has_puts = legs.any? { |leg| leg_is_put?(leg) }
        has_calls = legs.any? { |leg| leg_is_call?(leg) }

        has_puts && has_calls
      end

      # Check if this is a straddle
      #
      # @return [Boolean] True if straddle
      def straddle?
        return false unless leg_count == 2

        strikes = strike_prices
        expirations = expiration_dates

        # Same strike and expiration, one put and one call
        if strikes.size == 1 && expirations.size == 1
          has_put = legs.any? { |leg| leg_is_put?(leg) }
          has_call = legs.any? { |leg| leg_is_call?(leg) }
          has_put && has_call
        else
          false
        end
      end

      # Check if this is a strangle
      #
      # @return [Boolean] True if strangle
      def strangle?
        return false unless leg_count == 2

        strikes = strike_prices
        expirations = expiration_dates

        # Different strikes, same expiration, one put and one call
        if strikes.size == 2 && expirations.size == 1
          has_put = legs.any? { |leg| leg_is_put?(leg) }
          has_call = legs.any? { |leg| leg_is_call?(leg) }
          has_put && has_call
        else
          false
        end
      end

      # Check if this is a collar
      #
      # @return [Boolean] True if collar
      def collar?
        return false unless leg_count == 3 || leg_count == 2

        # Collar: long stock + long put + short call
        # Or just long put + short call (if stock is held separately)

        has_long_put = legs.any? { |leg| leg_is_put?(leg) && leg_is_long?(leg) }
        has_short_call = legs.any? { |leg| leg_is_call?(leg) && leg_is_short?(leg) }

        has_long_put && has_short_call
      end

      # Check if this is a ratio spread
      #
      # @return [Boolean] True if ratio spread
      def ratio_spread?
        return false unless multi_leg?

        # Ratio spread has unequal quantities
        quantities = legs.map { |leg| leg[:quantity].to_i.abs }.uniq
        quantities.size > 1
      end

      # Get max profit for the strategy
      #
      # @return [Float, nil] Maximum profit potential
      def max_profit
        # This would require complex calculations based on strategy type
        # Placeholder for strategy-specific calculations
        nil
      end

      # Get max loss for the strategy
      #
      # @return [Float, nil] Maximum loss potential
      def max_loss
        # This would require complex calculations based on strategy type
        # Placeholder for strategy-specific calculations
        nil
      end

      # Get breakeven points
      #
      # @return [Array<Float>] Breakeven points
      def breakeven_points
        # This would require complex calculations based on strategy type
        # Placeholder for strategy-specific calculations
        []
      end

      # Get strategy description
      #
      # @return [String] Human-readable strategy description
      def description
        if vertical_spread?
          "Vertical Spread"
        elsif calendar_spread?
          "Calendar Spread"
        elsif diagonal_spread?
          "Diagonal Spread"
        elsif iron_butterfly?
          "Iron Butterfly"
        elsif butterfly?
          "Butterfly Spread"
        elsif iron_condor?
          "Iron Condor"
        elsif condor?
          "Condor Spread"
        elsif straddle?
          "Straddle"
        elsif strangle?
          "Strangle"
        elsif collar?
          "Collar"
        elsif ratio_spread?
          "Ratio Spread"
        elsif multi_leg?
          "Multi-leg Strategy"
        else
          "Single Option"
        end
      end

      # Get formatted display string for the strategy
      #
      # @return [String] Formatted strategy string
      def to_display_string
        parts = []
        parts << description
        parts << underlying_symbol if underlying_symbol

        if strike_prices.any?
          parts << "Strikes: #{strike_prices.join("/")}"
        end

        if expiration_dates.any?
          parts << "Exp: #{expiration_dates.first}"
        end

        premium = net_premium
        if premium != 0
          parts << (premium > 0 ? "Credit: $#{premium.abs}" : "Debit: $#{premium.abs}")
        end

        parts.compact.join(" - ")
      end

      private

      # Check if a leg is a put option
      def leg_is_put?(leg)
        return false unless leg[:instrument]

        put_call = leg[:instrument][:putCall] || leg[:instrument][:put_call]
        put_call&.upcase == "PUT"
      end

      # Check if a leg is a call option
      def leg_is_call?(leg)
        return false unless leg[:instrument]

        put_call = leg[:instrument][:putCall] || leg[:instrument][:put_call]
        put_call&.upcase == "CALL"
      end

      # Check if a leg is long (buy)
      def leg_is_long?(leg)
        instruction = leg[:instruction]
        ["BUY", "BUY_TO_OPEN", "BUY_TO_CLOSE"].include?(instruction&.upcase)
      end

      # Check if a leg is short (sell)
      def leg_is_short?(leg)
        instruction = leg[:instruction]
        ["SELL", "SELL_TO_OPEN", "SELL_TO_CLOSE"].include?(instruction&.upcase)
      end
    end
  end
end
