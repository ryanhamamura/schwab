# frozen_string_literal: true

require_relative "base"

module Schwab
  module Resources
    # Resource wrapper for order objects
    # Provides order-specific helper methods and status checking
    class Order < Base
      # Set up field type coercions for order fields
      set_field_type :entered_time, :datetime
      set_field_type :close_time, :datetime
      set_field_type :filled_quantity, :float
      set_field_type :remaining_quantity, :float
      set_field_type :quantity, :float
      set_field_type :price, :float
      set_field_type :stop_price, :float
      set_field_type :limit_price, :float
      set_field_type :activation_price, :float
      set_field_type :commission, :float

      # Get order ID
      #
      # @return [String] The order ID
      def order_id
        self[:orderId] || self[:order_id] || self[:id]
      end
      alias_method :id, :order_id

      # Get account ID
      #
      # @return [String] The account ID
      def account_id
        self[:accountNumber] || self[:account_number] || self[:accountId] || self[:account_id]
      end

      # Get order status
      #
      # @return [String] The order status
      def status
        self[:status] || self[:orderStatus] || self[:order_status]
      end

      # Get order type
      #
      # @return [String] The order type (MARKET, LIMIT, STOP, etc.)
      def order_type
        self[:orderType] || self[:order_type] || self[:type]
      end

      # Get session (regular or extended hours)
      #
      # @return [String] The session (NORMAL, AM, PM, SEAMLESS)
      def session
        self[:session] || self[:tradingSession] || self[:trading_session]
      end

      # Get duration (time in force)
      #
      # @return [String] The duration (DAY, GTC, FOK, IOC, etc.)
      def duration
        self[:duration] || self[:timeInForce] || self[:time_in_force]
      end
      alias_method :time_in_force, :duration

      # Get instruction (BUY, SELL, etc.)
      #
      # @return [String] The instruction
      def instruction
        if order_legs&.first
          order_legs.first[:instruction]
        else
          self[:instruction] || self[:orderInstruction] || self[:order_instruction]
        end
      end

      # Get the symbol for single-leg orders
      #
      # @return [String, nil] The symbol
      def symbol
        if order_legs&.size == 1
          leg = order_legs.first
          leg[:instrument][:symbol] if leg[:instrument]
        elsif self[:symbol]
          self[:symbol]
        end
      end

      # Get quantity
      #
      # @return [Float] The quantity
      def quantity
        if order_legs&.first
          order_legs.first[:quantity].to_f
        else
          (self[:quantity] || self[:totalQuantity] || self[:total_quantity] || 0).to_f
        end
      end

      # Get filled quantity
      #
      # @return [Float] The filled quantity
      def filled_quantity
        (self[:filledQuantity] || self[:filled_quantity] || 0).to_f
      end

      # Get remaining quantity
      #
      # @return [Float] The remaining quantity
      def remaining_quantity
        (self[:remainingQuantity] || self[:remaining_quantity] || (quantity - filled_quantity)).to_f
      end

      # Get price (for limit/stop orders)
      #
      # @return [Float, nil] The price
      def price
        self[:price] || self[:limitPrice] || self[:limit_price] || self[:stopPrice] || self[:stop_price]
      end

      # Get limit price
      #
      # @return [Float, nil] The limit price
      def limit_price
        self[:limitPrice] || self[:limit_price]
      end

      # Get stop price
      #
      # @return [Float, nil] The stop price
      def stop_price
        self[:stopPrice] || self[:stop_price]
      end

      # Get activation price (for trailing stops)
      #
      # @return [Float, nil] The activation price
      def activation_price
        self[:activationPrice] || self[:activation_price]
      end

      # Get entered time
      #
      # @return [Time, String] The time order was entered
      def entered_time
        self[:enteredTime] || self[:entered_time] || self[:createdTime] || self[:created_time]
      end

      # Get close time (when order was filled/cancelled)
      #
      # @return [Time, String, nil] The close time
      def close_time
        self[:closeTime] || self[:close_time] || self[:filledTime] || self[:filled_time]
      end

      # Get order legs
      #
      # @return [Array] Array of order legs
      def order_legs
        self[:orderLegCollection] || self[:order_leg_collection] || self[:legs] || []
      end

      # Get child orders
      #
      # @return [Array<Order>] Array of child orders
      def child_orders
        children = self[:childOrderStrategies] || self[:child_order_strategies] || []
        children.map do |child_data|
          child_data.is_a?(Order) ? child_data : Order.new(child_data, client)
        end
      end

      # Check if order has child orders
      #
      # @return [Boolean] True if has child orders
      def has_children?
        !child_orders.empty?
      end

      # Get replaced orders
      #
      # @return [Array<Order>] Array of replaced orders
      def replaced_orders
        replaced = self[:replacingOrderCollection] || self[:replacing_order_collection] || []
        replaced.map do |order_data|
          order_data.is_a?(Order) ? order_data : Order.new(order_data, client)
        end
      end

      # Check if this is a complex order (multi-leg)
      #
      # @return [Boolean] True if complex order
      def complex?
        order_legs.size > 1
      end

      # Check if this is a single-leg order
      #
      # @return [Boolean] True if single-leg
      def single_leg?
        order_legs.size == 1
      end

      # Status check methods

      # Check if order is pending
      #
      # @return [Boolean] True if pending
      def pending?
        [
          "PENDING_ACTIVATION",
          "PENDING_APPROVAL",
          "PENDING_SUBMISSION",
          "AWAITING_PARENT_ORDER",
          "AWAITING_CONDITION",
          "AWAITING_MANUAL_REVIEW",
          "AWAITING_UR_OUT",
        ].include?(status&.upcase)
      end

      # Check if order is active/working
      #
      # @return [Boolean] True if active
      def active?
        ["ACCEPTED", "WORKING", "QUEUED"].include?(status&.upcase)
      end
      alias_method :working?, :active?
      alias_method :open?, :active?

      # Check if order is filled
      #
      # @return [Boolean] True if filled
      def filled?
        status&.upcase == "FILLED"
      end

      # Check if order is partially filled
      #
      # @return [Boolean] True if partially filled
      def partially_filled?
        filled_quantity > 0 && filled_quantity < quantity
      end

      # Check if order is cancelled
      #
      # @return [Boolean] True if cancelled
      def cancelled?
        ["CANCELED", "CANCELLED", "PENDING_CANCEL"].include?(status&.upcase)
      end
      alias_method :canceled?, :cancelled?

      # Check if order is rejected
      #
      # @return [Boolean] True if rejected
      def rejected?
        status&.upcase == "REJECTED"
      end

      # Check if order is expired
      #
      # @return [Boolean] True if expired
      def expired?
        status&.upcase == "EXPIRED"
      end

      # Check if order is replaced
      #
      # @return [Boolean] True if replaced
      def replaced?
        ["REPLACED", "PENDING_REPLACE"].include?(status&.upcase)
      end

      # Check if order is complete (filled, cancelled, rejected, or expired)
      #
      # @return [Boolean] True if complete
      def complete?
        filled? || cancelled? || rejected? || expired?
      end

      # Order type checks

      # Check if market order
      #
      # @return [Boolean] True if market order
      def market_order?
        order_type&.upcase == "MARKET"
      end

      # Check if limit order
      #
      # @return [Boolean] True if limit order
      def limit_order?
        order_type&.upcase == "LIMIT"
      end

      # Check if stop order
      #
      # @return [Boolean] True if stop order
      def stop_order?
        order_type&.upcase == "STOP"
      end

      # Check if stop limit order
      #
      # @return [Boolean] True if stop limit order
      def stop_limit_order?
        order_type&.upcase == "STOP_LIMIT"
      end

      # Check if trailing stop order
      #
      # @return [Boolean] True if trailing stop
      def trailing_stop?
        order_type&.upcase&.include?("TRAILING")
      end

      # Instruction checks

      # Check if buy order
      #
      # @return [Boolean] True if buy
      def buy?
        inst = instruction&.upcase
        ["BUY", "BUY_TO_COVER", "BUY_TO_OPEN", "BUY_TO_CLOSE"].include?(inst)
      end

      # Check if sell order
      #
      # @return [Boolean] True if sell
      def sell?
        inst = instruction&.upcase
        ["SELL", "SELL_SHORT", "SELL_TO_OPEN", "SELL_TO_CLOSE"].include?(inst)
      end

      # Check if opening order
      #
      # @return [Boolean] True if opening
      def opening?
        inst = instruction&.upcase
        ["BUY_TO_OPEN", "SELL_TO_OPEN"].include?(inst)
      end

      # Check if closing order
      #
      # @return [Boolean] True if closing
      def closing?
        inst = instruction&.upcase
        ["BUY_TO_CLOSE", "SELL_TO_CLOSE", "BUY_TO_COVER"].include?(inst)
      end

      # Check if option order
      #
      # @return [Boolean] True if option order
      def option_order?
        order_legs.any? do |leg|
          leg[:instrument] && leg[:instrument][:assetType] == "OPTION"
        end
      end

      # Check if equity order
      #
      # @return [Boolean] True if equity order
      def equity_order?
        order_legs.all? do |leg|
          leg[:instrument] && leg[:instrument][:assetType] == "EQUITY"
        end
      end

      # Session checks

      # Check if regular hours order
      #
      # @return [Boolean] True if regular hours
      def regular_hours?
        session&.upcase == "NORMAL"
      end

      # Check if extended hours order
      #
      # @return [Boolean] True if extended hours
      def extended_hours?
        ["AM", "PM", "SEAMLESS"].include?(session&.upcase)
      end

      # Duration checks

      # Check if day order
      #
      # @return [Boolean] True if day order
      def day_order?
        duration&.upcase == "DAY"
      end

      # Check if GTC order
      #
      # @return [Boolean] True if GTC
      def gtc?
        duration&.upcase == "GTC" || duration&.upcase == "GOOD_TILL_CANCEL"
      end

      # Check if FOK order
      #
      # @return [Boolean] True if FOK
      def fok?
        duration&.upcase == "FOK" || duration&.upcase == "FILL_OR_KILL"
      end

      # Check if IOC order
      #
      # @return [Boolean] True if IOC
      def ioc?
        duration&.upcase == "IOC" || duration&.upcase == "IMMEDIATE_OR_CANCEL"
      end

      # Calculate fill percentage
      #
      # @return [Float] The fill percentage (0-100)
      def fill_percentage
        return 0.0 if quantity.zero?

        ((filled_quantity / quantity) * 100).round(2)
      end

      # Get formatted display string for the order
      #
      # @return [String] Formatted order string
      def to_display_string
        parts = []
        parts << status
        parts << instruction
        parts << quantity.to_i.to_s
        parts << symbol if symbol
        parts << order_type
        parts << "@#{price}" if price
        parts << "(#{fill_percentage}% filled)" if partially_filled?

        parts.compact.join(" ")
      end
    end
  end
end
