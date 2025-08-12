# frozen_string_literal: true

RSpec.describe(Schwab) do
  it "has a version number" do
    expect(Schwab::VERSION).not_to(be(nil))
  end

  it "defines an error class" do
    expect(Schwab::Error).to(be < StandardError)
  end
end
