# frozen_string_literal: true

module Schwab
  # Resolves plain text account numbers to their encrypted hash values
  # required by the Schwab API for URL path parameters
  class AccountNumberResolver
    # Initialize a new resolver for the given client
    #
    # @param client [Schwab::Client] The client instance to use for API calls
    def initialize(client)
      @client = client
      @mappings = {}
      @loaded = false
      @mutex = Mutex.new
    end

    # Resolve an account number to its encrypted hash value
    #
    # @param account_number [String] Plain account number or encrypted hash value
    # @return [String] The encrypted hash value to use in API calls
    # @raise [Error] If the account number is not found
    # @example Resolve account number
    #   resolver.resolve("123456789")  # => "ABC123XYZ"
    #   resolver.resolve("ABC123XYZ")  # => "ABC123XYZ" (already encrypted)
    def resolve(account_number)
      return account_number if looks_like_hash?(account_number)

      @mutex.synchronize do
        load_mappings unless @loaded

        hash_value = @mappings[account_number.to_s]
        return hash_value if hash_value

        # Try refreshing mappings in case this is a new account
        refresh_mappings
        @mappings[account_number.to_s] || raise_account_not_found(account_number)
      end
    end

    # Refresh the account number mappings from the API
    #
    # @return [void]
    # @example Refresh mappings
    #   resolver.refresh!
    def refresh!
      @mutex.synchronize do
        refresh_mappings
      end
    end

    # Get all account numbers and their hash values
    #
    # @return [Hash<String, String>] Plain account number => hash value mapping
    # @example Get mappings
    #   resolver.mappings  # => {"123456789" => "ABC123XYZ"}
    def mappings
      @mutex.synchronize do
        load_mappings unless @loaded
        @mappings.dup
      end
    end

    # Check if the account number mappings are loaded
    #
    # @return [Boolean] True if mappings are loaded
    def loaded?
      @loaded
    end

    private

    # Check if a string looks like an encrypted hash value
    # Hash values are typically alphanumeric and longer than account numbers
    #
    # @param value [String] The value to check
    # @return [Boolean] True if it looks like a hash value
    def looks_like_hash?(value)
      # Schwab hash values are typically alphanumeric strings
      # that contain both letters and numbers (not purely numeric)
      str = value.to_s
      str.match?(/^[A-Za-z0-9]+$/) && str.match?(/[A-Za-z]/) && !str.match?(/^\d+$/)
    end

    # Load account number mappings from the API
    def load_mappings
      response = @client.get("/trader/v1/accounts/accountNumbers")

      @mappings.clear
      case response
      when Array
        response.each do |account|
          plain_number = account[:accountNumber] || account["accountNumber"]
          hash_value = account[:hashValue] || account["hashValue"]
          @mappings[plain_number.to_s] = hash_value.to_s if plain_number && hash_value
        end
      when Hash
        # Handle case where API returns wrapped response
        accounts = response[:accounts] || response["accounts"]
        if accounts.is_a?(Array)
          accounts.each do |account|
            plain_number = account[:accountNumber] || account["accountNumber"]
            hash_value = account[:hashValue] || account["hashValue"]
            @mappings[plain_number.to_s] = hash_value.to_s if plain_number && hash_value
          end
        end
      end

      @loaded = true
    end

    # Refresh mappings (clear cache and reload)
    def refresh_mappings
      @loaded = false
      load_mappings
    end

    # Raise an error for account not found
    def raise_account_not_found(account_number)
      raise Error, "Account number '#{account_number}' not found. " \
        "Available accounts: #{@mappings.keys.join(", ")}"
    end
  end
end
