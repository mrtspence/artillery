# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::RuntimeBase do
  let(:player) { create(:player) }
  let(:cartridge) { create(:cartridge_85mm, player:) }
  let(:match) { double("Match", id: 1) }

  describe "deterministic randomization" do
    let(:context) { { powder_charges: 3 } }

    it "produces same variance with same seed" do
      runtime1 = cartridge.to_runtime(match:, random_seed: 999)
      runtime2 = cartridge.to_runtime(match:, random_seed: 999)

      result1 = runtime1.resolve(context)
      result2 = runtime2.resolve(context)

      expect(result1[:base_initial_velocity]).to eq(result2[:base_initial_velocity])
      expect(result1[:shell_weight]).to eq(result2[:shell_weight])
    end

    it "produces different variance with different seed" do
      runtime1 = cartridge.to_runtime(match:, random_seed: 111)
      runtime2 = cartridge.to_runtime(match:, random_seed: 222)

      result1 = runtime1.resolve(context)
      result2 = runtime2.resolve(context)

      expect(result1[:base_initial_velocity]).not_to eq(result2[:base_initial_velocity])
      expect(result1[:shell_weight]).not_to eq(result2[:shell_weight])
    end

    it "ensures independent variance between different mechanisms" do
      cartridge1 = create(:cartridge_85mm, player:)
      cartridge2 = create(:cartridge_85mm, player:)

      # Same base seed, but different mechanism IDs
      runtime1 = cartridge1.to_runtime(match:, random_seed: 1000)
      runtime2 = cartridge2.to_runtime(match:, random_seed: 1000)

      result1 = runtime1.resolve(context)
      result2 = runtime2.resolve(context)

      # Should be different due to mechanism.id being added to seed
      expect(result1[:base_initial_velocity]).not_to eq(result2[:base_initial_velocity])
    end
  end
end
