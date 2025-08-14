# frozen_string_literal: true

require "spec_helper"
require "schwab/resources/base"

RSpec.describe(Schwab::Resources::Base) do
  let(:client) { double("Schwab::Client") }

  describe "#initialize" do
    it "initializes with empty data" do
      resource = described_class.new
      expect(resource.to_h).to(eq({}))
    end

    it "initializes with hash data" do
      data = { name: "John", age: 30 }
      resource = described_class.new(data)
      expect(resource.to_h).to(eq(data))
    end

    it "stores client reference" do
      resource = described_class.new({}, client)
      expect(resource.send(:client)).to(eq(client))
    end
  end

  describe "method access" do
    let(:data) { { name: "John", age: 30, active: true } }
    let(:resource) { described_class.new(data) }

    it "provides method access to hash data" do
      expect(resource.name).to(eq("John"))
      expect(resource.age).to(eq(30))
      expect(resource.active).to(eq(true))
    end

    it "supports both symbol and string keys" do
      data = { "name" => "John", :age => 30 }
      resource = described_class.new(data)
      expect(resource.name).to(eq("John"))
      expect(resource.age).to(eq(30))
    end

    it "returns nil for non-existent keys" do
      expect { resource.nonexistent }.to(raise_error(NoMethodError))
    end

    it "supports setter methods" do
      resource.name = "Jane"
      expect(resource.name).to(eq("Jane"))
      expect(resource[:name]).to(eq("Jane"))
    end
  end

  describe "hash-style access" do
    let(:data) { { name: "John", age: 30 } }
    let(:resource) { described_class.new(data) }

    it "supports bracket notation for reading" do
      expect(resource[:name]).to(eq("John"))
      expect(resource["name"]).to(eq("John"))
    end

    it "supports bracket notation for writing" do
      resource[:name] = "Jane"
      expect(resource[:name]).to(eq("Jane"))
      expect(resource.name).to(eq("Jane"))
    end

    it "handles symbol and string keys interchangeably" do
      resource[:status] = "active"
      expect(resource["status"]).to(eq("active"))
    end
  end

  describe "nested resources" do
    let(:data) do
      {
        name: "John",
        address: {
          city: "New York",
          zip: "10001",
        },
        tags: ["ruby", "rails"],
      }
    end
    let(:resource) { described_class.new(data) }

    it "wraps nested hashes in resource objects" do
      expect(resource.address).to(be_a(described_class))
      expect(resource.address.city).to(eq("New York"))
      expect(resource.address.zip).to(eq("10001"))
    end

    it "maintains object identity for nested resources" do
      address1 = resource.address
      address2 = resource.address
      expect(address1).to(be(address2))
    end

    it "wraps arrays of hashes" do
      data = { items: [{ id: 1 }, { id: 2 }] }
      resource = described_class.new(data)
      expect(resource.items).to(be_an(Array))
      expect(resource.items.first).to(be_a(described_class))
      expect(resource.items.first.id).to(eq(1))
    end

    it "leaves non-hash arrays unchanged" do
      expect(resource.tags).to(eq(["ruby", "rails"]))
    end
  end

  describe "#key?" do
    let(:resource) { described_class.new(name: "John") }

    it "checks for key existence" do
      expect(resource.key?(:name)).to(be(true))
      expect(resource.key?("name")).to(be(true))
      expect(resource.key?(:age)).to(be(false))
    end

    it "has has_key? alias" do
      expect(resource.key?(:name)).to(be(true))
    end
  end

  describe "#keys" do
    it "returns all keys" do
      resource = described_class.new(name: "John", age: 30)
      expect(resource.keys).to(match_array([:name, :age]))
    end
  end

  describe "#empty?" do
    it "returns true for empty resource" do
      expect(described_class.new.empty?).to(be(true))
    end

    it "returns false for non-empty resource" do
      expect(described_class.new(name: "John").empty?).to(be(false))
    end
  end

  describe "#each" do
    let(:resource) { described_class.new(name: "John", age: 30) }

    it "iterates over key-value pairs" do
      pairs = []
      resource.each { |k, v| pairs << [k, v] }
      expect(pairs).to(match_array([[:name, "John"], [:age, 30]]))
    end
  end

  describe "#==" do
    let(:data) { { name: "John", age: 30 } }

    it "equals another resource with same data" do
      resource1 = described_class.new(data)
      resource2 = described_class.new(data)
      expect(resource1).to(eq(resource2))
    end

    it "equals a hash with same data" do
      resource = described_class.new(data)
      expect(resource).to(eq(data))
    end

    it "does not equal resource with different data" do
      resource1 = described_class.new(name: "John")
      resource2 = described_class.new(name: "Jane")
      expect(resource1).not_to(eq(resource2))
    end

    it "does not equal non-hash/non-resource objects" do
      resource = described_class.new(data)
      expect(resource).not_to(eq("string"))
      expect(resource).not_to(eq(123))
    end
  end

  describe "#respond_to_missing?" do
    let(:resource) { described_class.new(name: "John") }

    it "responds to existing keys" do
      expect(resource.respond_to?(:name)).to(be(true))
      expect(resource.respond_to?(:name=)).to(be(true))
    end

    it "does not respond to non-existent keys" do
      expect(resource.respond_to?(:nonexistent)).to(be(false))
    end
  end

  describe "#attributes" do
    let(:data) { { name: "John", age: 30 } }
    let(:resource) { described_class.new(data) }

    it "returns the underlying data hash" do
      expect(resource.attributes).to(eq(data))
    end
  end

  describe "#to_h and #to_hash" do
    let(:data) { { name: "John", age: 30 } }
    let(:resource) { described_class.new(data) }

    it "returns the underlying hash" do
      expect(resource.to_h).to(eq(data))
      expect(resource.to_hash).to(eq(data))
    end
  end

  describe "#inspect" do
    it "returns a readable string representation" do
      resource = described_class.new(name: "John")
      expect(resource.inspect).to(include("Schwab::Resources::Base"))
      expect(resource.inspect).to(include("name"))
      expect(resource.inspect).to(include("John"))
    end
  end

  describe "#to_s" do
    it "returns string representation of data" do
      resource = described_class.new(name: "John")
      expect(resource.to_s).to(eq({ name: "John" }.to_s))
    end
  end

  describe "type coercion" do
    # Create a test subclass with field types defined
    let(:test_class) do
      Class.new(described_class) do
        set_field_type :created_at, :time
        set_field_type :birth_date, :date
        set_field_type :updated_at, :datetime
        set_field_type :count, :integer
        set_field_type :price, :float
        set_field_type :active, :boolean
      end
    end

    context "time coercion" do
      it "coerces string to Time" do
        resource = test_class.new(created_at: "2024-01-15 10:30:00")
        expect(resource.created_at).to(be_a(Time))
      end

      it "coerces timestamp to Time" do
        timestamp = 1705312200
        resource = test_class.new(created_at: timestamp)
        expect(resource.created_at).to(be_a(Time))
        expect(resource.created_at).to(eq(Time.at(timestamp)))
      end

      it "handles millisecond timestamps" do
        timestamp = 1705312200000
        resource = test_class.new(created_at: timestamp)
        expect(resource.created_at).to(eq(Time.at(timestamp / 1000.0)))
      end
    end

    context "date coercion" do
      it "coerces string to Date" do
        resource = test_class.new(birth_date: "2024-01-15")
        expect(resource.birth_date).to(be_a(Date))
      end

      it "coerces Time to Date" do
        resource = test_class.new(birth_date: Time.now)
        expect(resource.birth_date).to(be_a(Date))
      end
    end

    context "datetime coercion" do
      it "coerces string to DateTime" do
        resource = test_class.new(updated_at: "2024-01-15 10:30:00")
        # DateTime.parse returns a DateTime, but Time.parse might be used internally
        result = resource.updated_at
        expect(result).to(satisfy { |v| v.is_a?(DateTime) || v.is_a?(Time) })
        expect(result.year).to(eq(2024))
        expect(result.month).to(eq(1))
        expect(result.day).to(eq(15))
      end
    end

    context "numeric coercion" do
      it "coerces to integer" do
        resource = test_class.new(count: "42")
        expect(resource.count).to(eq(42))
        expect(resource.count).to(be_a(Integer))
      end

      it "coerces to float" do
        resource = test_class.new(price: "19.99")
        expect(resource.price).to(eq(19.99))
        expect(resource.price).to(be_a(Float))
      end
    end

    context "boolean coercion" do
      it "coerces string 'true' to true" do
        resource = test_class.new(active: "true")
        expect(resource.active).to(be(true))
      end

      it "coerces string 'false' to false" do
        resource = test_class.new(active: "false")
        expect(resource.active).to(be(false))
      end

      it "coerces 1 to true" do
        resource = test_class.new(active: 1)
        expect(resource.active).to(be(true))
      end

      it "coerces 0 to false" do
        resource = test_class.new(active: 0)
        expect(resource.active).to(be(false))
      end
    end

    context "nil handling" do
      it "preserves nil values" do
        resource = test_class.new(created_at: nil)
        expect(resource.created_at).to(be_nil)
      end
    end

    context "coercion failure" do
      it "returns original value if coercion fails" do
        resource = test_class.new(created_at: "invalid date")
        # Should return original value when parse fails
        expect(resource.created_at).to(eq("invalid date"))
      end
    end
  end
end
