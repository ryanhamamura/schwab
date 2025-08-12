# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into(:webmock)
  config.configure_rspec_metadata!

  # Filter sensitive data
  config.filter_sensitive_data("<SCHWAB_CLIENT_ID>") { ENV["SCHWAB_CLIENT_ID"] }
  config.filter_sensitive_data("<SCHWAB_CLIENT_SECRET>") { ENV["SCHWAB_CLIENT_SECRET"] }
  config.filter_sensitive_data("<SCHWAB_REDIRECT_URI>") { ENV["SCHWAB_REDIRECT_URI"] }
  config.filter_sensitive_data("<ACCESS_TOKEN>") do |interaction|
    interaction.request.headers["Authorization"]&.first&.gsub(/Bearer .+/, "Bearer <ACCESS_TOKEN>")
  end

  # Allow localhost connections for test server if needed
  config.ignore_localhost = true

  # Set default cassette options
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body],
  }
end
