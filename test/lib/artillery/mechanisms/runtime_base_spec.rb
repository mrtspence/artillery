# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::RuntimeBase do
  let(:player) { create(:player) }
  let(:cartridge) { create(:cartridge_85mm, player:) }
  let(:match) { double("Match", id: 1) }

  describe "deterministic randomization" do
    let(:context) { Artillery::Mechanisms::PipelineContext.new({ powder_charges: 3 }) }

    it "produces same variance with same seed" do
      runtime1 = cartridge.to_runtime(match:, random_seed: 999)
      runtime2 = cartridge.to_runtime(match:, random_seed: 999)

      transforms1 = runtime1.resolve(context)
      transforms2 = runtime2.resolve(context)

      velocity1 = transforms1.find { |t| t.key == :base_initial_velocity }.value
      velocity2 = transforms2.find { |t| t.key == :base_initial_velocity }.value
      weight1 = transforms1.find { |t| t.key == :shell_weight }.value
      weight2 = transforms2.find { |t| t.key == :shell_weight }.value

      expect(velocity1).to eq(velocity2)
      expect(weight1).to eq(weight2)
    end

    it "produces different variance with different seed" do
      runtime1 = cartridge.to_runtime(match:, random_seed: 111)
      runtime2 = cartridge.to_runtime(match:, random_seed: 222)

      transforms1 = runtime1.resolve(context)
      transforms2 = runtime2.resolve(context)

      velocity1 = transforms1.find { |t| t.key == :base_initial_velocity }.value
      velocity2 = transforms2.find { |t| t.key == :base_initial_velocity }.value
      weight1 = transforms1.find { |t| t.key == :shell_weight }.value
      weight2 = transforms2.find { |t| t.key == :shell_weight }.value

      expect(velocity1).not_to eq(velocity2)
      expect(weight1).not_to eq(weight2)
    end

    it "ensures independent variance between different mechanisms" do
      cartridge1 = create(:cartridge_85mm, player:)
      cartridge2 = create(:cartridge_85mm, player:)

      # Same base seed, but different mechanism IDs
      runtime1 = cartridge1.to_runtime(match:, random_seed: 1000)
      runtime2 = cartridge2.to_runtime(match:, random_seed: 1000)

      transforms1 = runtime1.resolve(context)
      transforms2 = runtime2.resolve(context)

      velocity1 = transforms1.find { |t| t.key == :base_initial_velocity }.value
      velocity2 = transforms2.find { |t| t.key == :base_initial_velocity }.value

      # Should be different due to mechanism.id being added to seed
      expect(velocity1).not_to eq(velocity2)
    end
  end
end
