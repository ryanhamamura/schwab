# frozen_string_literal: true

require "time"
require "date"

module Schwab
  # Resource objects for wrapping API responses with convenient access patterns
  module Resources
    # Base class for resource objects that wrap API response hashes
    # Provides Sawyer::Resource-like functionality for method access to hash data
    #
    # @example Creating a resource
    #   data = { name: "John", age: 30, address: { city: "NYC" } }
    #   resource = Schwab::Resources::Base.new(data)
    #   resource.name # => "John"
    #   resource[:age] # => 30
    #   resource.address.city # => "NYC"
    class Base
      class << self
        # Define fields that should be coerced to specific types
        # Subclasses can override this to specify their field types
        def field_types
          @field_types ||= {}
        end

        # Set field types for automatic coercion
        def set_field_type(field, type)
          field_types[field.to_sym] = type
        end
      end

      # Initialize a new resource with data
      #
      # @param data [Hash] The data to wrap
      # @param client [Schwab::Client, nil] Optional client for API calls
      def initialize(data = {}, client = nil)
        @data = data || {}
        @client = client
        @_nested_resources = {}
      end

      # Access data via method calls
      #
      # @param method_name [Symbol] The method name
      # @param args [Array] Method arguments
      # @param block [Proc] Optional block
      # @return [Object] The value from the data hash
      def method_missing(method_name, *args, &block)
        key = method_name.to_s

        # Check for setter methods
        if key.end_with?("=")
          key = key[0...-1]
          @data[key.to_sym] = args.first
          @data[key] = args.first
          return args.first
        end

        # Try symbol key first, then string key
        if @data.key?(method_name)
          wrap_value(@data[method_name], method_name)
        elsif @data.key?(key)
          wrap_value(@data[key], key.to_sym)
        else
          super
        end
      end

      # Check if method exists
      #
      # @param method_name [Symbol] The method name
      # @param include_private [Boolean] Include private methods
      # @return [Boolean] True if method exists
      def respond_to_missing?(method_name, include_private = false)
        key = method_name.to_s
        is_setter = key.end_with?("=")
        key = key[0...-1] if is_setter

        # Always respond to setters, or check if key exists for getters
        is_setter || @data.key?(method_name) || @data.key?(key.to_sym) || @data.key?(key) || super
      end

      # Hash-style access to data
      #
      # @param key [Symbol, String] The key to access
      # @return [Object] The value
      def [](key)
        value = @data[key.to_sym] || @data[key.to_s]
        wrap_value(value, key.to_sym)
      end

      # Hash-style setter
      #
      # @param key [Symbol, String] The key to set
      # @param value [Object] The value to set
      def []=(key, value)
        @data[key.to_sym] = value
        @data[key.to_s] = value
      end

      # Check if key exists
      #
      # @param key [Symbol, String] The key to check
      # @return [Boolean] True if key exists
      def key?(key)
        @data.key?(key.to_sym) || @data.key?(key.to_s)
      end
      alias_method :has_key?, :key?

      # Get all keys
      #
      # @return [Array] Array of keys
      def keys
        @data.keys
      end

      # Convert to hash
      #
      # @return [Hash] The underlying data hash
      def to_h
        @data
      end
      alias_method :to_hash, :to_h

      # Get attributes as hash
      #
      # @return [Hash] The underlying data hash
      def attributes
        @data
      end

      # Inspect the resource
      #
      # @return [String] String representation
      def inspect
        "#<#{self.class.name} #{@data.inspect}>"
      end

      # Convert to string
      #
      # @return [String] String representation
      def to_s
        @data.to_s
      end

      # Equality comparison
      #
      # @param other [Object] Object to compare
      # @return [Boolean] True if equal
      def ==(other)
        case other
        when self.class
          @data == other.to_h
        when Hash
          @data == other
        else
          false
        end
      end

      # Iterate over data
      #
      # @yield [key, value] Yields each key-value pair
      def each(&block)
        @data.each(&block)
      end

      # Check if resource has no data
      #
      # @return [Boolean] True if empty
      def empty?
        @data.empty?
      end

      protected

      # Get the client instance
      attr_reader :client

      private

      # Wrap nested hashes in resource objects and coerce types
      #
      # @param value [Object] The value to wrap
      # @param field_name [Symbol, nil] The field name for type coercion
      # @return [Object] The wrapped and coerced value
      def wrap_value(value, field_name = nil)
        # First apply type coercion if field type is defined
        if field_name && self.class.field_types[field_name.to_sym]
          value = coerce_value(value, self.class.field_types[field_name.to_sym])
        end

        case value
        when Hash
          # Cache nested resources to maintain object identity
          @_nested_resources[value.object_id] ||= self.class.new(value, @client)
        when Array
          value.map { |item| wrap_value(item) }
        else
          value
        end
      end

      # Coerce a value to a specific type
      #
      # @param value [Object] The value to coerce
      # @param type [Symbol, Class] The target type
      # @return [Object] The coerced value
      def coerce_value(value, type)
        return if value.nil?

        case type
        when :time, Time
          coerce_to_time(value)
        when :date, Date
          coerce_to_date(value)
        when :datetime, DateTime
          coerce_to_datetime(value)
        when :integer, Integer
          value.to_i
        when :float, Float
          value.to_f
        when :decimal, BigDecimal
          require "bigdecimal"
          BigDecimal(value.to_s)
        when :boolean
          coerce_to_boolean(value)
        when :symbol, Symbol
          value.to_sym
        else
          value
        end
      rescue StandardError
        value # Return original value if coercion fails
      end

      # Coerce to Time
      def coerce_to_time(value)
        case value
        when Time
          value
        when Date, DateTime
          value.to_time
        when String
          Time.parse(value)
        when Integer, Float
          # Assume milliseconds timestamp if large number
          value > 9999999999 ? Time.at(value / 1000.0) : Time.at(value)
        else
          value
        end
      end

      # Coerce to Date
      def coerce_to_date(value)
        case value
        when Date
          value
        when Time, DateTime
          value.to_date
        when String
          Date.parse(value)
        else
          value
        end
      end

      # Coerce to DateTime
      def coerce_to_datetime(value)
        case value
        when DateTime, Time
          value
        when Date
          value.to_time
        when String
          Time.parse(value)
        when Integer, Float
          # Assume milliseconds timestamp if large number
          value > 9999999999 ? Time.at(value / 1000.0) : Time.at(value)
        else
          value
        end
      end

      # Coerce to boolean
      def coerce_to_boolean(value)
        case value
        when TrueClass, FalseClass
          value
        when String
          value.downcase == "true" || value == "1"
        when Integer
          value == 1
        else
          !!value
        end
      end
    end
  end
end
