# frozen_string_literal: true

module Schwab
  # Base error class for all Schwab SDK errors
  class Error < StandardError; end

  # Base class for all API-related errors
  class ApiError < Error
    attr_reader :status, :response_body, :response_headers

    def initialize(message = nil, status: nil, response_body: nil, response_headers: nil)
      super(message)
      @status = status
      @response_body = response_body
      @response_headers = response_headers
    end
  end

  # Raised when API returns 401 Unauthorized
  class AuthenticationError < ApiError; end

  # Raised when the access token has expired
  class TokenExpiredError < AuthenticationError; end

  # Raised when API returns 403 Forbidden
  class AuthorizationError < ApiError; end

  # Raised when API returns 404 Not Found
  class NotFoundError < ApiError; end

  # Raised when API returns 429 Too Many Requests
  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil, **options)
      super(message, **options)
      @retry_after = retry_after
    end
  end

  # Raised when API returns 5xx Server Error
  class ServerError < ApiError; end

  # Raised when API returns 400 Bad Request
  class BadRequestError < ApiError; end

  # Raised when API returns an unexpected status code
  class UnexpectedResponseError < ApiError; end
end
