# frozen_string_literal: true

require "uri"

module Schwab
  # Account Management API endpoints for retrieving account information,
  # positions, transactions, and orders
  module Accounts
    class << self
      # Get all accounts for the authenticated user
      #
      # @param fields [String, Array<String>, nil] Fields to include (e.g., "positions", "orders")
      # @param client [Schwab::Client, nil] Optional client instance (uses default if not provided)
      # @return [Array<Hash>, Array<Resources::Account>] List of accounts
      # @example Get all accounts
      #   Schwab::Accounts.get_accounts
      # @example Get accounts with positions
      #   Schwab::Accounts.get_accounts(fields: "positions")
      def get_accounts(fields: nil, client: nil)
        client ||= default_client
        params = {}
        params[:fields] = normalize_fields(fields) if fields

        response = client.get("/trader/v1/accounts", params, Resources::Account)
        # API returns accounts in a wrapper, extract the array
        response.is_a?(Hash) && response[:accounts] ? response[:accounts] : response
      end
      alias_method :list_accounts, :get_accounts

      # Get a specific account by account number
      #
      # @param account_number [String] The account number
      # @param fields [String, Array<String>, nil] Fields to include
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash, Resources::Account] Account details
      # @example Get account with positions and orders
      #   Schwab::Accounts.get_account("123456", fields: ["positions", "orders"])
      def get_account(account_number, fields: nil, client: nil)
        client ||= default_client
        path = "/trader/v1/accounts/#{encode_account_number(account_number, client)}"
        params = {}
        params[:fields] = normalize_fields(fields) if fields

        client.get(path, params, Resources::Account)
      end

      # Get positions for a specific account
      #
      # @param account_number [String] The account number
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Array<Hash>, Array<Resources::Position>] List of positions
      # @example Get all positions
      #   Schwab::Accounts.get_positions("123456")
      def get_positions(account_number, client: nil)
        account_data = get_account(account_number, fields: "positions", client: client)

        if account_data.is_a?(Hash)
          # Positions are nested under securitiesAccount
          securities_account = account_data["securitiesAccount"] || account_data[:securitiesAccount]
          positions = securities_account ? (securities_account["positions"] || securities_account[:positions]) : nil
        elsif account_data.respond_to?(:positions)
          positions = account_data.positions
        end

        positions || []
      end

      # Get transactions for a specific account
      #
      # @param account_number [String] The account number
      # @param types [String, Array<String>] Transaction types to filter (REQUIRED). Valid values:
      #   TRADE, RECEIVE_AND_DELIVER, DIVIDEND_OR_INTEREST, ACH_RECEIPT, ACH_DISBURSEMENT,
      #   CASH_RECEIPT, CASH_DISBURSEMENT, ELECTRONIC_FUND, WIRE_OUT, WIRE_IN, JOURNAL,
      #   MEMORANDUM, MARGIN_CALL, MONEY_MARKET, SMA_ADJUSTMENT
      # @param start_date [Date, Time, String] Start date for transactions (ISO-8601 format, REQUIRED)
      # @param end_date [Date, Time, String] End date for transactions (ISO-8601 format, REQUIRED)
      # @param symbol [String, nil] Filter by symbol
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Array<Hash>, Array<Resources::Transaction>] List of transactions
      # @example Get all trade transactions
      #   Schwab::Accounts.get_transactions("123456",
      #     types: "TRADE",
      #     start_date: "2024-01-01",
      #     end_date: "2024-01-31"
      #   )
      # @example Get trades for AAPL in date range
      #   Schwab::Accounts.get_transactions("123456",
      #     types: "TRADE",
      #     symbol: "AAPL",
      #     start_date: "2024-01-01",
      #     end_date: "2024-01-31"
      #   )
      def get_transactions(account_number, types: nil, start_date: nil, end_date: nil, symbol: nil, client: nil)
        client ||= default_client
        path = "/trader/v1/accounts/#{encode_account_number(account_number, client)}/transactions"

        params = {}
        params[:types] = normalize_transaction_types(types) if types
        params[:startDate] = format_date(start_date) if start_date
        params[:endDate] = format_date(end_date) if end_date
        params[:symbol] = symbol.upcase if symbol

        client.get(path, params, Resources::Transaction)
      end

      # Get a specific transaction
      #
      # @param account_number [String] The account number
      # @param transaction_id [String] The transaction ID
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash, Resources::Transaction] Transaction details
      # @example Get transaction details
      #   Schwab::Accounts.get_transaction("123456", "trans789")
      def get_transaction(account_number, transaction_id, client: nil)
        client ||= default_client
        path = "/trader/v1/accounts/#{encode_account_number(account_number, client)}/transactions/#{transaction_id}"

        client.get(path, {}, Resources::Transaction)
      end

      # Get orders for a specific account
      #
      # @param account_number [String] The account number
      # @param from_entered_time [Time, DateTime, String, nil] Start time for orders (ISO-8601 format required)
      # @param to_entered_time [Time, DateTime, String, nil] End time for orders (ISO-8601 format required)
      # @param status [String, Array<String>, nil] Order status filter. Valid values:
      #   AWAITING_PARENT_ORDER, AWAITING_CONDITION, AWAITING_STOP_CONDITION, AWAITING_MANUAL_REVIEW,
      #   ACCEPTED, AWAITING_UR_OUT, PENDING_ACTIVATION, QUEUED, WORKING, REJECTED, PENDING_CANCEL,
      #   CANCELED, PENDING_REPLACE, REPLACED, FILLED, EXPIRED, NEW, AWAITING_RELEASE_TIME,
      #   PENDING_ACKNOWLEDGEMENT, PENDING_RECALL, UNKNOWN
      # @param max_results [Integer, nil] Maximum number of results (defaults to 3000)
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Array<Hash>, Array<Resources::Order>] List of orders
      # @example Get all orders with time range
      #   Schwab::Accounts.get_orders("123456",
      #     from_entered_time: "2024-03-29T00:00:00.000Z",
      #     to_entered_time: "2024-03-30T00:00:00.000Z"
      #   )
      # @example Get working orders
      #   Schwab::Accounts.get_orders("123456", status: "WORKING")
      def get_orders(account_number, from_entered_time: nil, to_entered_time: nil, status: nil, max_results: nil, client: nil)
        client ||= default_client
        path = "/trader/v1/accounts/#{encode_account_number(account_number, client)}/orders"

        params = {}
        params[:fromEnteredTime] = format_datetime(from_entered_time) if from_entered_time
        params[:toEnteredTime] = format_datetime(to_entered_time) if to_entered_time
        params[:status] = normalize_order_status(status) if status
        params[:maxResults] = max_results if max_results

        client.get(path, params, Resources::Order)
      end

      # Get all orders for all accounts
      #
      # @param from_entered_time [Time, DateTime, String, nil] Start time for orders
      # @param to_entered_time [Time, DateTime, String, nil] End time for orders
      # @param status [String, Array<String>, nil] Order status filter
      # @param max_results [Integer, nil] Maximum number of results
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Array<Hash>, Array<Resources::Order>] List of orders
      # @example Get all orders across all accounts
      #   Schwab::Accounts.get_all_orders
      # @example Get all filled orders today
      #   Schwab::Accounts.get_all_orders(
      #     from_entered_time: Date.today,
      #     status: "FILLED"
      #   )
      def get_all_orders(from_entered_time: nil, to_entered_time: nil, status: nil, max_results: nil, client: nil)
        client ||= default_client
        path = "/trader/v1/orders"

        params = {}
        params[:fromEnteredTime] = format_datetime(from_entered_time) if from_entered_time
        params[:toEnteredTime] = format_datetime(to_entered_time) if to_entered_time
        params[:status] = normalize_order_status(status) if status
        params[:maxResults] = max_results if max_results

        client.get(path, params, Resources::Order)
      end

      # Get a specific order
      #
      # @param account_number [String] The account number
      # @param order_id [String] The order ID
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash, Resources::Order] Order details
      # @example Get order details
      #   Schwab::Accounts.get_order("123456", "order789")
      def get_order(account_number, order_id, client: nil)
        client ||= default_client
        path = "/trader/v1/accounts/#{encode_account_number(account_number, client)}/orders/#{order_id}"

        client.get(path, {}, Resources::Order)
      end

      # Get account numbers and their encrypted hash values
      #
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Array<Hash>] Array of account number/hash value pairs
      # @example Get account numbers
      #   Schwab::Accounts.get_account_numbers
      #   # => [{accountNumber: "123456789", hashValue: "ABC123XYZ"}, ...]
      def get_account_numbers(client: nil)
        client ||= default_client
        client.get("/trader/v1/accounts/accountNumbers")
      end

      # Get user preferences (across all accounts)
      #
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash] User preferences
      # @example Get user preferences
      #   Schwab::Accounts.get_user_preferences
      def get_user_preferences(client: nil)
        client ||= default_client
        client.get("/trader/v1/userPreference")
      end

      # Preview an order before placing it
      #
      # @param account_number [String] The account number
      # @param order_data [Hash] Order details to preview
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash] Order preview with estimated costs, commissions, and margin requirements
      # @example Preview a buy order
      #   Schwab::Accounts.preview_order("123456", {
      #     orderType: "MARKET",
      #     session: "NORMAL",
      #     duration: "DAY",
      #     orderStrategyType: "SINGLE",
      #     orderLegCollection: [{
      #       instruction: "BUY",
      #       quantity: 10,
      #       instrument: {
      #         symbol: "AAPL",
      #         assetType: "EQUITY"
      #       }
      #     }]
      #   })
      def preview_order(account_number, order_data, client: nil)
        client ||= default_client
        path = "/trader/v1/accounts/#{encode_account_number(account_number, client)}/previewOrder"

        client.post(path, order_data)
      end

      private

      def default_client
        Schwab.client || raise(Error, "No client configured. Set Schwab.client or pass a client instance.")
      end

      def encode_account_number(account_number, client = nil)
        client ||= default_client
        encrypted_number = client.resolve_account_number(account_number)
        URI.encode_www_form_component(encrypted_number)
      end

      def encode_symbol(symbol)
        URI.encode_www_form_component(symbol.to_s.upcase)
      end

      def normalize_fields(fields)
        case fields
        when Array
          fields.join(",")
        when String
          fields
        else
          fields.to_s
        end
      end

      def normalize_transaction_types(types)
        case types
        when Array
          types.map(&:to_s).map(&:upcase).join(",")
        when String
          types.upcase
        else
          types.to_s.upcase
        end
      end

      def normalize_order_status(status)
        case status
        when Array
          status.map(&:to_s).map(&:upcase).join(",")
        when String
          status.upcase
        else
          status.to_s.upcase
        end
      end

      def format_date(date)
        case date
        when Date
          date.iso8601
        when Time, DateTime
          date.to_date.iso8601
        when String
          # If string already contains time info, preserve it
          if date.include?("T") && date.include?(":")
            date
          else
            Date.parse(date).iso8601
          end
        else
          date.to_s
        end
      end

      def format_datetime(datetime)
        case datetime
        when Time
          datetime.iso8601
        when DateTime
          datetime.to_time.iso8601
        when Date
          datetime.to_time.iso8601
        when String
          Time.parse(datetime).iso8601
        else
          datetime.to_s
        end
      end
    end
  end
end
