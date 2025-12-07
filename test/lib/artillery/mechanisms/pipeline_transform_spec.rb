# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::PipelineTransform do
  describe "#initialize" do
    it "creates a transform with all required parameters" do
      transform = described_class.new(key: :velocity, value: 100, operation: :increment)

      expect(transform.key).to eq(:velocity)
      expect(transform.value).to eq(100)
      expect(transform.operation).to eq(:increment)
    end

    it "raises error if operation not specified" do
      expect {
        described_class.new(key: :velocity, value: 100)
      }.to raise_error(ArgumentError, /missing keyword.*operation/i)
    end

    it "raises error for invalid operation" do
      expect {
        described_class.new(key: :velocity, value: 100, operation: :invalid)
      }.to raise_error(ArgumentError, /Invalid operation/)
    end

    it "raises error for non-symbol key" do
      expect {
        described_class.new(key: "velocity", value: 100, operation: :increment)
      }.to raise_error(ArgumentError, /Key must be a Symbol/)
    end
  end

  describe "#apply" do
    context "with :set operation" do
      let(:transform) { described_class.new(key: :velocity, value: 100, operation: :set) }

      it "sets value ignoring current value" do
        expect(transform.apply(50)).to eq(100)
      end

      it "sets value when current is nil" do
        expect(transform.apply(nil)).to eq(100)
      end

      it "overwrites any existing value" do
        expect(transform.apply(999)).to eq(100)
      end
    end

    context "with :increment operation" do
      let(:transform) { described_class.new(key: :velocity, value: 50, operation: :increment) }

      it "adds to current value" do
        expect(transform.apply(100)).to eq(150)
      end

      it "treats nil as 0" do
        expect(transform.apply(nil)).to eq(50)
      end

      it "handles negative increments (subtraction)" do
        decrement = described_class.new(key: :velocity, value: -30, operation: :increment)
        expect(decrement.apply(100)).to eq(70)
      end

      it "allows multiple increments to accumulate" do
        value = 100
        value = transform.apply(value)  # 150
        value = transform.apply(value)  # 200
        expect(value).to eq(200)
      end
    end

    context "with :multiply operation" do
      let(:transform) { described_class.new(key: :velocity, value: 1.5, operation: :multiply) }

      it "multiplies current value" do
        expect(transform.apply(100)).to eq(150.0)
      end

      it "returns 0 when current is nil" do
        expect(transform.apply(nil)).to eq(0)
      end

      it "handles fractional multipliers" do
        half = described_class.new(key: :velocity, value: 0.5, operation: :multiply)
        expect(half.apply(100)).to eq(50.0)
      end

      it "allows chaining multiple multipliers" do
        value = 100
        value = transform.apply(value)  # 150
        double = described_class.new(key: :velocity, value: 2, operation: :multiply)
        value = double.apply(value)     # 300
        expect(value).to eq(300.0)
      end
    end
  end

  describe "#multiplicative?" do
    it "returns true for multiply operation" do
      transform = described_class.new(key: :velocity, value: 2, operation: :multiply)

      expect(transform.multiplicative?).to be true
    end

    it "returns false for set operation" do
      transform = described_class.new(key: :velocity, value: 100, operation: :set)

      expect(transform.multiplicative?).to be false
    end

    it "returns false for increment operation" do
      transform = described_class.new(key: :velocity, value: 50, operation: :increment)

      expect(transform.multiplicative?).to be false
    end
  end

  describe "#additive?" do
    it "returns true for set operation" do
      transform = described_class.new(key: :velocity, value: 100, operation: :set)

      expect(transform.additive?).to be true
    end

    it "returns true for increment operation" do
      transform = described_class.new(key: :velocity, value: 50, operation: :increment)

      expect(transform.additive?).to be true
    end

    it "returns false for multiply operation" do
      transform = described_class.new(key: :velocity, value: 2, operation: :multiply)

      expect(transform.additive?).to be false
    end
  end

  describe "#to_s and #inspect" do
    it "provides readable string representation" do
      transform = described_class.new(key: :velocity, value: 100, operation: :increment)

      expect(transform.to_s).to eq("PipelineTransform(velocity: increment 100)")
      expect(transform.inspect).to eq(transform.to_s)
    end
  end

  describe "operation semantics" do
    it ":set establishes a base value" do
      transform = described_class.new(key: :damage, value: 100, operation: :set)

      expect(transform.apply(nil)).to eq(100)
      expect(transform.apply(50)).to eq(100)
    end

    it ":increment modifies relative to current value" do
      base = described_class.new(key: :damage, value: 100, operation: :set)
      bonus = described_class.new(key: :damage, value: 25, operation: :increment)

      value = base.apply(nil)      # 100
      value = bonus.apply(value)   # 125
      expect(value).to eq(125)
    end

    it ":multiply scales current value" do
      base = described_class.new(key: :damage, value: 100, operation: :set)
      multiplier = described_class.new(key: :damage, value: 1.5, operation: :multiply)

      value = base.apply(nil)            # 100
      value = multiplier.apply(value)    # 150
      expect(value).to eq(150.0)
    end

    it "operations can be combined in sequence" do
      # Simulate: base 100, +20 bonus, ×1.5 multiplier
      base = described_class.new(key: :damage, value: 100, operation: :set)
      bonus = described_class.new(key: :damage, value: 20, operation: :increment)
      multiplier = described_class.new(key: :damage, value: 1.5, operation: :multiply)

      value = nil
      value = base.apply(value)        # 100
      value = bonus.apply(value)       # 120
      value = multiplier.apply(value)  # 180
      expect(value).to eq(180.0)
    end
  end
end
