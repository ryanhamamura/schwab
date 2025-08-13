# frozen_string_literal: true

require "uri"

module Schwab
  # Market Data API endpoints for retrieving quotes, price history, and market information
  module MarketData
    class << self
      # Get quotes for one or more symbols
      #
      # @param symbols [String, Array<String>] Symbol(s) to get quotes for
      # @param fields [String, Array<String>, nil] Quote fields to include (e.g., "quote", "fundamental")
      # @param indicative [Boolean] Whether to include indicative quotes
      # @param client [Schwab::Client, nil] Optional client instance (uses default if not provided)
      # @return [Hash] Quote data for the requested symbols
      # @example Get quotes for multiple symbols
      #   Schwab::MarketData.get_quotes(["AAPL", "MSFT"])
      # @example Get quotes with specific fields
      #   Schwab::MarketData.get_quotes("AAPL", fields: ["quote", "fundamental"])
      def get_quotes(symbols, fields: nil, indicative: false, client: nil)
        client ||= default_client
        params = {
          symbols: normalize_symbols(symbols),
          indicative: indicative,
        }
        params[:fields] = normalize_fields(fields) if fields

        client.get("/marketdata/v1/quotes", params)
      end

      # Get detailed quote for a single symbol
      #
      # @param symbol [String] The symbol to get a quote for
      # @param fields [String, Array<String>, nil] Quote fields to include
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash] Detailed quote data for the symbol
      # @example Get a single quote
      #   Schwab::MarketData.get_quote("AAPL")
      def get_quote(symbol, fields: nil, client: nil)
        client ||= default_client
        path = "/marketdata/v1/#{URI.encode_www_form_component(symbol)}/quotes"
        params = {}
        params[:fields] = normalize_fields(fields) if fields

        client.get(path, params)
      end

      # Get price history for a symbol
      #
      # @param symbol [String] The symbol to get price history for
      # @param period_type [String, nil] The type of period ("day", "month", "year", "ytd")
      # @param period [Integer, nil] The number of periods
      # @param frequency_type [String, nil] The type of frequency ("minute", "daily", "weekly", "monthly")
      # @param frequency [Integer, nil] The frequency value
      # @param start_date [Time, Date, String, Integer, nil] Start date for history
      # @param end_date [Time, Date, String, Integer, nil] End date for history
      # @param need_extended_hours [Boolean] Include extended hours data
      # @param need_previous_close [Boolean] Include previous close data
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash] Price history data with candles
      # @example Get 5 days of history
      #   Schwab::MarketData.get_quote_history("AAPL", period_type: "day", period: 5)
      def get_quote_history(symbol, period_type: nil, period: nil, frequency_type: nil,
        frequency: nil, start_date: nil, end_date: nil,
        need_extended_hours: true, need_previous_close: false, client: nil)
        client ||= default_client
        path = "/marketdata/v1/pricehistory"

        params = { symbol: symbol }
        params[:periodType] = period_type if period_type
        params[:period] = period if period
        params[:frequencyType] = frequency_type if frequency_type
        params[:frequency] = frequency if frequency
        params[:startDate] = format_timestamp(start_date) if start_date
        params[:endDate] = format_timestamp(end_date) if end_date
        params[:needExtendedHoursData] = need_extended_hours
        params[:needPreviousClose] = need_previous_close

        client.get(path, params)
      end

      # Get market movers for an index
      #
      # @param index [String] The index symbol (e.g., "$SPX", "$DJI")
      # @param direction [String, nil] Direction of movement ("up" or "down")
      # @param change [String, nil] Type of change ("percent" or "value")
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash] Market movers data
      # @example Get top movers for S&P 500
      #   Schwab::MarketData.get_movers("$SPX", direction: "up", change: "percent")
      def get_movers(index, direction: nil, change: nil, client: nil)
        client ||= default_client
        path = "/marketdata/v1/movers/#{URI.encode_www_form_component(index)}"

        params = {}
        params[:direction] = direction if direction
        params[:change] = change if change

        client.get(path, params)
      end

      # Get market hours for one or more markets
      #
      # @param markets [String, Array<String>] Market(s) to get hours for (e.g., "EQUITY", "OPTION")
      # @param date [Date, Time, String, nil] Date to get market hours for
      # @param client [Schwab::Client, nil] Optional client instance
      # @return [Hash] Market hours information
      # @example Get equity market hours
      #   Schwab::MarketData.get_market_hours("EQUITY")
      def get_market_hours(markets, date: nil, client: nil)
        client ||= default_client
        params = {
          markets: normalize_markets(markets),
        }
        params[:date] = format_date(date) if date

        client.get("/marketdata/v1/markets", params)
      end

      # Get market hours for a single market
      # Note: This appears to be the same endpoint as get_market_hours
      # but with a single market instead of multiple
      def get_market_hour(market_id, date: nil, client: nil)
        get_market_hours(market_id, date: date, client: client)
      end

      private

      def default_client
        raise Error, "No client provided and no global configuration available" unless Schwab.configuration

        @default_client ||= Client.new(
          access_token: Schwab.configuration.access_token,
          refresh_token: Schwab.configuration.refresh_token,
        )
      end

      def normalize_symbols(symbols)
        Array(symbols).join(",")
      end

      def normalize_fields(fields)
        Array(fields).join(",")
      end

      def normalize_markets(markets)
        Array(markets).join(",")
      end

      def format_timestamp(time)
        case time
        when Time, DateTime
          (time.to_f * 1000).to_i
        when Date
          (time.to_time.to_f * 1000).to_i
        when Integer
          time
        when String
          (Time.parse(time).to_f * 1000).to_i
        else
          raise ArgumentError, "Invalid timestamp format: #{time.class}"
        end
      end

      def format_date(date)
        case date
        when Date
          date.strftime("%Y-%m-%d")
        when Time, DateTime
          date.strftime("%Y-%m-%d")
        when String
          Date.parse(date).strftime("%Y-%m-%d")
        else
          raise ArgumentError, "Invalid date format: #{date.class}"
        end
      end
    end
  end
end
