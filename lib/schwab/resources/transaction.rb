# frozen_string_literal: true

require_relative "base"

module Schwab
  module Resources
    # Resource wrapper for transaction objects
    # Provides transaction-specific helper methods and type identification
    class Transaction < Base
      # Set up field type coercions for transaction fields
      set_field_type :transaction_date, :datetime
      set_field_type :settlement_date, :date
      set_field_type :net_amount, :float
      set_field_type :fees, :float
      set_field_type :commission, :float
      set_field_type :price, :float
      set_field_type :quantity, :float
      set_field_type :amount, :float
      set_field_type :cost, :float

      # Get transaction ID
      #
      # @return [String] The transaction ID
      def transaction_id
        self[:transactionId] || self[:transaction_id] || self[:id]
      end
      alias_method :id, :transaction_id

      # Get transaction type
      #
      # @return [String] The transaction type
      def transaction_type
        self[:transactionType] || self[:transaction_type] || self[:type]
      end
      alias_method :type, :transaction_type

      # Get transaction subtype
      #
      # @return [String] The transaction subtype
      def transaction_subtype
        self[:transactionSubType] || self[:transaction_sub_type] || self[:subtype]
      end
      alias_method :subtype, :transaction_subtype

      # Get transaction date
      #
      # @return [Time, Date, String] The transaction date
      def transaction_date
        self[:transactionDate] || self[:transaction_date] || self[:date]
      end
      alias_method :date, :transaction_date

      # Get settlement date
      #
      # @return [Date, String] The settlement date
      def settlement_date
        self[:settlementDate] || self[:settlement_date]
      end

      # Get transaction description
      #
      # @return [String] The transaction description
      def description
        self[:description] || self[:transactionDescription] || self[:transaction_description]
      end

      # Get the symbol associated with the transaction
      #
      # @return [String, nil] The symbol
      def symbol
        if self[:transactionItem]
          begin
            self[:transactionItem][:instrument][:symbol]
          rescue
            nil
          end
        elsif self[:instrument]
          self[:instrument][:symbol]
        else
          self[:symbol]
        end
      end

      # Get the quantity
      #
      # @return [Float] The quantity
      def quantity
        if self[:transactionItem]
          (self[:transactionItem][:quantity] || self[:transactionItem][:amount] || 0).to_f
        else
          (self[:quantity] || self[:amount] || 0).to_f
        end
      end

      # Get the price
      #
      # @return [Float, nil] The price
      def price
        if self[:transactionItem]
          self[:transactionItem][:price]
        else
          self[:price]
        end
      end

      # Get the net amount
      #
      # @return [Float] The net amount
      def net_amount
        (self[:netAmount] || self[:net_amount] || 0).to_f
      end
      alias_method :amount, :net_amount

      # Get fees
      #
      # @return [Float] The fees
      def fees
        if self[:fees]
          fees_data = self[:fees]
          total = 0.0

          # Sum up different fee types if fees is a hash
          if fees_data.is_a?(Hash)
            fees_data.each_value { |v| total += v.to_f if v }
          else
            total = fees_data.to_f
          end

          total
        else
          0.0
        end
      end

      # Get commission
      #
      # @return [Float] The commission
      def commission
        begin
          self[:commission] || self[:fees][:commission]
        rescue
          0
        end.to_f
      end

      # Check if this is a trade transaction
      #
      # @return [Boolean] True if trade
      def trade?
        ["TRADE", "BUY", "SELL", "BUY_TO_OPEN", "BUY_TO_CLOSE", "SELL_TO_OPEN", "SELL_TO_CLOSE"].include?(transaction_type&.upcase)
      end

      # Check if this is a buy transaction
      #
      # @return [Boolean] True if buy
      def buy?
        type_upper = transaction_type&.upcase
        ["BUY", "BUY_TO_OPEN", "BUY_TO_CLOSE"].include?(type_upper) ||
          (type_upper == "TRADE" && quantity > 0)
      end

      # Check if this is a sell transaction
      #
      # @return [Boolean] True if sell
      def sell?
        type_upper = transaction_type&.upcase
        ["SELL", "SELL_TO_OPEN", "SELL_TO_CLOSE"].include?(type_upper) ||
          (type_upper == "TRADE" && quantity < 0)
      end

      # Check if this is a dividend transaction
      #
      # @return [Boolean] True if dividend
      def dividend?
        type_upper = transaction_type&.upcase
        ["DIVIDEND", "DIVIDEND_REINVEST", "QUALIFIED_DIVIDEND"].include?(type_upper)
      end

      # Check if this is an interest transaction
      #
      # @return [Boolean] True if interest
      def interest?
        type_upper = transaction_type&.upcase
        ["INTEREST", "INTEREST_INCOME", "MARGIN_INTEREST"].include?(type_upper)
      end

      # Check if this is a deposit
      #
      # @return [Boolean] True if deposit
      def deposit?
        type_upper = transaction_type&.upcase
        ["DEPOSIT", "ELECTRONIC_FUND", "WIRE_IN", "ACH_DEPOSIT"].include?(type_upper)
      end

      # Check if this is a withdrawal
      #
      # @return [Boolean] True if withdrawal
      def withdrawal?
        type_upper = transaction_type&.upcase
        ["WITHDRAWAL", "WIRE_OUT", "ACH_WITHDRAWAL"].include?(type_upper)
      end

      # Check if this is a transfer
      #
      # @return [Boolean] True if transfer
      def transfer?
        type_upper = transaction_type&.upcase
        ["TRANSFER", "INTERNAL_TRANSFER", "JOURNAL"].include?(type_upper)
      end

      # Check if this is a fee transaction
      #
      # @return [Boolean] True if fee
      def fee?
        type_upper = transaction_type&.upcase
        ["FEE", "COMMISSION", "SERVICE_FEE", "TRANSACTION_FEE"].include?(type_upper)
      end

      # Check if this is an option transaction
      #
      # @return [Boolean] True if option transaction
      def option?
        if self[:transactionItem]
          asset_type = begin
            self[:transactionItem][:instrument][:assetType]
          rescue
            nil
          end
          asset_type == "OPTION"
        elsif self[:instrument]
          self[:instrument][:assetType] == "OPTION"
        else
          # Check if transaction type indicates options
          type_upper = transaction_type&.upcase || ""
          type_upper.include?("OPTION") ||
            ["BUY_TO_OPEN", "BUY_TO_CLOSE", "SELL_TO_OPEN", "SELL_TO_CLOSE", "ASSIGNMENT", "EXERCISE"].include?(type_upper)
        end
      end

      # Check if this is an assignment
      #
      # @return [Boolean] True if assignment
      def assignment?
        type_upper = transaction_type&.upcase
        type_upper == "ASSIGNMENT" || type_upper == "OPTION_ASSIGNMENT"
      end

      # Check if this is an exercise
      #
      # @return [Boolean] True if exercise
      def exercise?
        type_upper = transaction_type&.upcase
        type_upper == "EXERCISE" || type_upper == "OPTION_EXERCISE"
      end

      # Check if this is an expiration
      #
      # @return [Boolean] True if expiration
      def expiration?
        type_upper = transaction_type&.upcase
        type_upper == "EXPIRATION" || type_upper == "OPTION_EXPIRATION"
      end

      # Get the cost basis for trade transactions
      #
      # @return [Float, nil] The cost basis
      def cost_basis
        return unless trade?

        if price && quantity
          (price * quantity.abs).round(2)
        else
          net_amount.abs
        end
      end

      # Get total cost including fees
      #
      # @return [Float, nil] The total cost
      def total_cost
        return unless trade?

        cost = cost_basis || 0
        cost + fees + commission
      end

      # Check if transaction is pending
      #
      # @return [Boolean] True if pending
      def pending?
        status = self[:status] || self[:transactionStatus] || self[:transaction_status]
        status&.upcase == "PENDING"
      end

      # Check if transaction is completed
      #
      # @return [Boolean] True if completed
      def completed?
        status = self[:status] || self[:transactionStatus] || self[:transaction_status]
        status.nil? || status.upcase == "COMPLETED" || status.upcase == "EXECUTED"
      end

      # Check if transaction is cancelled
      #
      # @return [Boolean] True if cancelled
      def cancelled?
        status = self[:status] || self[:transactionStatus] || self[:transaction_status]
        status&.upcase == "CANCELLED" || status&.upcase == "CANCELED"
      end

      # Get account ID associated with transaction
      #
      # @return [String, nil] The account ID
      def account_id
        self[:accountNumber] || self[:account_number] || self[:accountId] || self[:account_id]
      end

      # Get formatted display string for the transaction
      #
      # @return [String] Formatted transaction string
      def to_display_string
        parts = []
        parts << transaction_date.to_s if transaction_date
        parts << transaction_type
        parts << symbol if symbol
        parts << "#{quantity} @ $#{price}" if quantity && price
        parts << "$#{net_amount}" if net_amount != 0

        parts.compact.join(" - ")
      end
    end
  end
end
