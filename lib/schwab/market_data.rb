# frozen_string_literal: true

require "uri"

module Schwab
  module MarketData
    class << self
      def get_quotes(symbols, fields: nil, indicative: false, client: nil)
        client ||= default_client
        params = {
          symbols: normalize_symbols(symbols),
          indicative: indicative,
        }
        params[:fields] = normalize_fields(fields) if fields

        client.get("/marketdata/v1/quotes", params)
      end

      def get_quote(symbol, fields: nil, client: nil)
        client ||= default_client
        path = "/marketdata/v1/#{URI.encode_www_form_component(symbol)}/quotes"
        params = {}
        params[:fields] = normalize_fields(fields) if fields

        client.get(path, params)
      end

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

      def get_movers(index, direction: nil, change: nil, client: nil)
        client ||= default_client
        path = "/marketdata/v1/movers/#{URI.encode_www_form_component(index)}"

        params = {}
        params[:direction] = direction if direction
        params[:change] = change if change

        client.get(path, params)
      end

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
