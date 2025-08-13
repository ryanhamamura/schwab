# frozen_string_literal: true

require_relative "schwab/version"
require_relative "schwab/error"
require_relative "schwab/configuration"
require_relative "schwab/oauth"
require_relative "schwab/client"

module Schwab
  class << self
    # Global configuration instance
    attr_writer :configuration

    # Access the global configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the SDK globally
    #
    # @example
    #   Schwab.configure do |config|
    #     config.client_id = ENV['SCHWAB_CLIENT_ID']
    #     config.client_secret = ENV['SCHWAB_CLIENT_SECRET']
    #     config.redirect_uri = ENV['SCHWAB_REDIRECT_URI']
    #     config.logger = Rails.logger
    #   end
    #
    # @yield [Configuration] The configuration instance
    def configure
      yield(configuration)
    end

    # Reset the global configuration to defaults
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
