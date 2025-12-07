# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::PipelineContext do
  describe "#initialize" do
    it "creates context with player input" do
      context = described_class.new({ angle_deg: 45, powder_charges: 3 })

      expect(context.get(:angle_deg)).to eq(45)
      expect(context.get(:powder_charges)).to eq(3)
    end

    it "creates context with empty input" do
      context = described_class.new

      expect(context.player_input).to eq({})
    end
  end

  describe "#set_or_update" do
    let(:context) { described_class.new }

    it "applies a :set transform to establish initial value" do
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )

      context.set_or_update(transform)

      expect(context.get(:velocity)).to eq(500)
    end

    it "applies an :increment transform to existing value" do
      set_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      increment_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 50,
        operation: :increment
      )

      context.set_or_update(set_transform)
      context.set_or_update(increment_transform)

      expect(context.get(:velocity)).to eq(550)
    end

    it "applies :increment transform to nil value" do
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :bonus,
        value: 25,
        operation: :increment
      )

      context.set_or_update(transform)

      expect(context.get(:bonus)).to eq(25)
    end

    it "applies a :multiply transform to existing value" do
      set_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :damage,
        value: 100,
        operation: :set
      )
      multiply_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :damage,
        value: 1.5,
        operation: :multiply
      )

      context.set_or_update(set_transform)
      context.set_or_update(multiply_transform)

      expect(context.get(:damage)).to eq(150.0)
    end

    it "initializes to 0 for :multiply on non-existent key" do
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :multiplier,
        value: 2,
        operation: :multiply
      )

      context.set_or_update(transform)

      expect(context.get(:multiplier)).to eq(0)
    end

    it "returns self for method chaining" do
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :value,
        value: 100,
        operation: :set
      )

      result = context.set_or_update(transform)

      expect(result).to be(context)
    end

    it "raises error if given non-PipelineTransform" do
      expect {
        context.set_or_update({ key: :value, value: 100 })
      }.to raise_error(ArgumentError, /Expected PipelineTransform/)
    end
  end

  describe "#get" do
    it "retrieves value from transforms" do
      context = described_class.new
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(transform)

      expect(context.get(:velocity)).to eq(500)
    end

    it "falls back to player_input if not in transforms" do
      context = described_class.new({ powder_charges: 3 })

      expect(context.get(:powder_charges)).to eq(3)
    end

    it "returns nil if key not found" do
      context = described_class.new

      expect(context.get(:nonexistent)).to be_nil
    end

    it "prefers transforms over player_input" do
      context = described_class.new({ velocity: 400 })
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(transform)

      expect(context.get(:velocity)).to eq(500)
    end
  end

  describe "#[] (array access)" do
    it "works like #get" do
      context = described_class.new({ angle_deg: 45 })

      expect(context[:angle_deg]).to eq(45)
    end
  end

  describe "#has?" do
    it "returns true for keys in transforms" do
      context = described_class.new
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(transform)

      expect(context.has?(:velocity)).to be true
    end

    it "returns true for keys in player_input" do
      context = described_class.new({ powder_charges: 3 })

      expect(context.has?(:powder_charges)).to be true
    end

    it "returns false for non-existent keys" do
      context = described_class.new

      expect(context.has?(:nonexistent)).to be false
    end
  end

  describe "#transformed?" do
    it "returns true for keys that have been transformed" do
      context = described_class.new
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(transform)

      expect(context.transformed?(:velocity)).to be true
    end

    it "returns false for keys only in player_input" do
      context = described_class.new({ powder_charges: 3 })

      expect(context.transformed?(:powder_charges)).to be false
    end

    it "returns false for non-existent keys" do
      context = described_class.new

      expect(context.transformed?(:nonexistent)).to be false
    end
  end

  describe "#to_ballistic_inputs" do
    it "extracts ballistic engine parameters" do
      context = described_class.new({ angle_deg: 45 })
      velocity_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :base_initial_velocity,
        value: 550,
        operation: :set
      )
      weight_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :shell_weight,
        value: 8.4,
        operation: :set
      )
      context.set_or_update(velocity_transform)
      context.set_or_update(weight_transform)

      inputs = context.to_ballistic_inputs

      expect(inputs[:angle_deg]).to eq(45)
      expect(inputs[:initial_velocity]).to eq(550)  # Maps base_initial_velocity
      expect(inputs[:shell_weight]).to eq(8.4)
      expect(inputs[:deflection_deg]).to eq(0.0)    # Default
      expect(inputs[:area_of_effect]).to eq(0.0)    # Default
      expect(inputs[:surface_area]).to eq(0.05)     # Default
    end

    it "uses defaults for missing values" do
      context = described_class.new

      inputs = context.to_ballistic_inputs

      expect(inputs[:angle_deg]).to eq(45.0)
      expect(inputs[:initial_velocity]).to eq(500.0)
      expect(inputs[:shell_weight]).to eq(25.0)
      expect(inputs[:deflection_deg]).to eq(0.0)
      expect(inputs[:area_of_effect]).to eq(0.0)
      expect(inputs[:surface_area]).to eq(0.05)
    end

    it "maps base_initial_velocity to initial_velocity" do
      context = described_class.new
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :base_initial_velocity,
        value: 600,
        operation: :set
      )
      context.set_or_update(transform)

      inputs = context.to_ballistic_inputs

      expect(inputs[:initial_velocity]).to eq(600)
    end

    it "prefers initial_velocity over base_initial_velocity" do
      context = described_class.new
      base_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :base_initial_velocity,
        value: 500,
        operation: :set
      )
      override_transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :initial_velocity,
        value: 600,
        operation: :set
      )
      context.set_or_update(base_transform)
      context.set_or_update(override_transform)

      inputs = context.to_ballistic_inputs

      expect(inputs[:initial_velocity]).to eq(600)
    end
  end

  describe "#to_h" do
    it "merges player_input and transforms" do
      context = described_class.new({ angle_deg: 45, powder_charges: 3 })
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 550,
        operation: :set
      )
      context.set_or_update(transform)

      hash = context.to_h

      expect(hash[:angle_deg]).to eq(45)
      expect(hash[:powder_charges]).to eq(3)
      expect(hash[:velocity]).to eq(550)
    end

    it "transforms override player_input in output" do
      context = described_class.new({ velocity: 400 })
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(transform)

      hash = context.to_h

      expect(hash[:velocity]).to eq(500)
    end
  end

  describe "#freeze!" do
    it "freezes the context and its data" do
      context = described_class.new({ angle_deg: 45 })
      transform = Artillery::Mechanisms::PipelineTransform.new(
        key: :velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(transform)

      context.freeze!

      expect(context).to be_frozen
      expect(context.player_input).to be_frozen
      expect(context.transforms).to be_frozen
    end
  end

  describe "complex pipeline scenario" do
    it "handles multiple mechanisms contributing to same key" do
      context = described_class.new({ powder_charges: 3 })

      # Base cartridge sets velocity
      base_velocity = Artillery::Mechanisms::PipelineTransform.new(
        key: :initial_velocity,
        value: 500,
        operation: :set
      )
      context.set_or_update(base_velocity)

      # Upgraded powder adds bonus
      powder_bonus = Artillery::Mechanisms::PipelineTransform.new(
        key: :initial_velocity,
        value: 50,
        operation: :increment
      )
      context.set_or_update(powder_bonus)

      # Barrel multiplier applies
      barrel_multiplier = Artillery::Mechanisms::PipelineTransform.new(
        key: :initial_velocity,
        value: 1.1,
        operation: :multiply
      )
      context.set_or_update(barrel_multiplier)

      # Final: (500 + 50) × 1.1 = 605
      expect(context.get(:initial_velocity)).to eq(605.0)
    end
  end
end
