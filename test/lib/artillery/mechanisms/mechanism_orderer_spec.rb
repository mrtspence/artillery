# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::MechanismOrderer do
  let(:player) { create(:player) }
  let(:match) { double("Match", id: 1) }
  let(:random_seed) { 12345 }

  describe "#ordered" do
    context "with single runtime" do
      let(:cartridge) { create(:cartridge_85mm, player:) }
      let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
      let(:orderer) { described_class.new([runtime]) }

      it "returns the runtime" do
        expect(orderer.ordered).to eq([runtime])
      end
    end

    context "with multiple runtimes in random order" do
      let(:cartridge_10) { create(:cartridge_85mm, player:, priority: 10) }
      let(:cartridge_5) { create(:cartridge_85mm, player:, priority: 5) }
      let(:cartridge_20) { create(:cartridge_85mm, player:, priority: 20) }

      let(:runtime_10) { cartridge_10.to_runtime(match:, random_seed:) }
      let(:runtime_5) { cartridge_5.to_runtime(match:, random_seed: random_seed + 1) }
      let(:runtime_20) { cartridge_20.to_runtime(match:, random_seed: random_seed + 2) }

      it "orders by priority ascending" do
        # Pass in deliberately wrong order
        orderer = described_class.new([runtime_20, runtime_5, runtime_10])

        ordered = orderer.ordered

        expect(ordered[0].mechanism.priority).to eq(5)
        expect(ordered[1].mechanism.priority).to eq(10)
        expect(ordered[2].mechanism.priority).to eq(20)
      end
    end

    context "with duplicate priorities" do
      let(:cartridge_a) { create(:cartridge_85mm, player:, priority: 10) }
      let(:cartridge_b) { create(:cartridge_85mm, player:, priority: 10) }

      let(:runtime_a) { cartridge_a.to_runtime(match:, random_seed:) }
      let(:runtime_b) { cartridge_b.to_runtime(match:, random_seed: random_seed + 1) }

      it "maintains stable sort order" do
        orderer = described_class.new([runtime_a, runtime_b])

        ordered = orderer.ordered

        # Both have priority 10, order should be preserved
        expect(ordered).to eq([runtime_a, runtime_b])
      end
    end

    context "with priority ranges" do
      let(:input_converter) { create(:cartridge_85mm, player:, priority: 5) }
      let(:base_provider) { create(:cartridge_85mm, player:, priority: 10) }
      let(:primary_modifier) { create(:cartridge_85mm, player:, priority: 25) }
      let(:metadata_provider) { create(:cartridge_85mm, player:, priority: 95) }

      let(:runtimes) do
        [
          metadata_provider,
          input_converter,
          primary_modifier,
          base_provider
        ].map.with_index { |m, i| m.to_runtime(match:, random_seed: random_seed + i) }
      end

      it "respects priority range guidelines" do
        orderer = described_class.new(runtimes)
        ordered = orderer.ordered

        priorities = ordered.map { |r| r.mechanism.priority }

        expect(priorities).to eq([5, 10, 25, 95])
      end
    end
  end
end
