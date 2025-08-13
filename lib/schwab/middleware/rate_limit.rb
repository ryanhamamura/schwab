# frozen_string_literal: true

require "faraday"

module Schwab
  module Middleware
    # Faraday middleware for handling rate limits with exponential backoff
    class RateLimit < Faraday::Middleware
      DEFAULT_MAX_RETRIES = 3
      DEFAULT_RETRY_DELAY = 1 # seconds
      DEFAULT_BACKOFF_FACTOR = 2
      RETRY_STATUSES = [429, 503].freeze # Rate limited and Service Unavailable

      def initialize(app, options = {})
        super(app)
        @max_retries = options[:max_retries] || DEFAULT_MAX_RETRIES
        @retry_delay = options[:retry_delay] || DEFAULT_RETRY_DELAY
        @backoff_factor = options[:backoff_factor] || DEFAULT_BACKOFF_FACTOR
        @logger = options[:logger]
      end

      def call(env)
        retries = 0
        delay = @retry_delay

        begin
          response = @app.call(env)

          # Check if we should retry this response
          if should_retry?(response) && retries < @max_retries
            retries += 1

            # Check for Retry-After header
            retry_after = response.headers["retry-after"]
            wait_time = retry_after ? parse_retry_after(retry_after) : delay

            log_retry(env, response, retries, wait_time)

            # Wait before retrying
            sleep(wait_time)

            # Exponential backoff for next retry
            delay *= @backoff_factor

            # Retry the request by raising a custom error
            raise Faraday::RetriableResponse.new(nil, response)
          end

          response
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          # Retry on network errors
          if retries < @max_retries
            retries += 1

            log_retry_error(env, e, retries, delay)

            sleep(delay)
            delay *= @backoff_factor

            retry
          else
            raise e
          end
        rescue Faraday::RetriableResponse
          # This is our custom retry signal
          retry
        end
      end

      private

      def should_retry?(response)
        RETRY_STATUSES.include?(response.status)
      end

      def parse_retry_after(value)
        # Retry-After can be in seconds (integer) or HTTP date
        if value.match?(/^\d+$/)
          value.to_i
        else
          # Parse HTTP date and calculate seconds to wait
          retry_time = Time.httpdate(value)
          wait_seconds = retry_time - Time.now
          wait_seconds > 0 ? wait_seconds : @retry_delay
        end
      rescue ArgumentError
        # If we can't parse it, use default delay
        @retry_delay
      end

      def log_retry(env, response, attempt, wait_time)
        return unless @logger

        @logger.info(
          "[RateLimit] Retrying request to #{env[:url].path} " \
            "(attempt #{attempt}/#{@max_retries}, status: #{response.status}, " \
            "waiting: #{wait_time}s)",
        )
      end

      def log_retry_error(env, error, attempt, wait_time)
        return unless @logger

        @logger.info(
          "[RateLimit] Retrying request to #{env[:url].path} after error " \
            "(attempt #{attempt}/#{@max_retries}, error: #{error.class}, " \
            "waiting: #{wait_time}s)",
        )
      end
    end
  end
end
