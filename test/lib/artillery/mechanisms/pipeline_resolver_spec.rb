# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::PipelineResolver do
  let(:player) { create(:player) }
  let(:match) { double("Match", id: 1) }
  let(:random_seed) { 12345 }

  describe "#resolve" do
    context "with single cartridge mechanism" do
      let(:cartridge) { create(:cartridge_85mm, player:) }
      let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
      let(:player_input) { { powder_charges: 3 } }
      let(:resolver) { described_class.new([runtime], player_input) }

      it "resolves cartridge outputs" do
        context = resolver.resolve

        expect(context).to include(:base_initial_velocity)
        expect(context).to include(:shell_weight)
        expect(context).to include(:surface_area)
        expect(context).to include(:caliber_mm)
      end

      it "preserves player input" do
        context = resolver.resolve

        expect(context[:powder_charges]).to eq(3)
      end

      it "applies velocity variance" do
        context = resolver.resolve

        # Base: 400 + (3 * 50) = 550 m/s, with ±5% variance
        expect(context[:base_initial_velocity]).to be_between(522.5, 577.5)
      end

      it "applies weight variance" do
        context = resolver.resolve

        # Base: 8.4 kg with ±2% variance
        expect(context[:shell_weight]).to be_between(8.232, 8.568)
      end
    end

    context "with multiple mechanisms in pipeline" do
      let(:cartridge_a) { create(:cartridge_85mm, player:, priority: 10) }
      let(:cartridge_b) { create(:cartridge_85mm, player:, priority: 20) }

      let(:runtime_a) { cartridge_a.to_runtime(match:, random_seed:) }
      let(:runtime_b) { cartridge_b.to_runtime(match:, random_seed: random_seed + 1) }

      let(:player_input) { { powder_charges: 2 } }
      let(:resolver) { described_class.new([runtime_b, runtime_a], player_input) }

      it "executes mechanisms in priority order" do
        allow(runtime_a).to receive(:resolve).and_call_original
        allow(runtime_b).to receive(:resolve).and_call_original

        resolver.resolve

        expect(runtime_a).to have_received(:resolve).ordered
        expect(runtime_b).to have_received(:resolve).ordered
      end
    end
  end

  describe "#ballistic_attributes" do
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
    let(:player_input) { { powder_charges: 2, angle_deg: 30 } }
    let(:resolver) { described_class.new([runtime], player_input) }

    it "extracts ballistic engine parameters" do
      attrs = resolver.ballistic_attributes

      expect(attrs).to include(:angle_deg)
      expect(attrs).to include(:initial_velocity)
      expect(attrs).to include(:shell_weight)
      expect(attrs).to include(:deflection_deg)
      expect(attrs).to include(:area_of_effect)
      expect(attrs).to include(:surface_area)
    end

    it "uses resolved initial_velocity from base_initial_velocity" do
      attrs = resolver.ballistic_attributes

      # Cartridge outputs base_initial_velocity, which should map to initial_velocity
      expect(attrs[:initial_velocity]).to be_a(Numeric)
    end

    it "preserves player input angle" do
      attrs = resolver.ballistic_attributes

      expect(attrs[:angle_deg]).to eq(30)
    end

    it "provides default values for missing parameters" do
      attrs = resolver.ballistic_attributes

      expect(attrs[:deflection_deg]).to eq(0.0)
      expect(attrs[:area_of_effect]).to eq(0.0)
    end
  end

  describe "#turn_order_delay" do
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
    let(:player_input) { {} }

    context "with no delay mechanisms" do
      let(:resolver) { described_class.new([runtime], player_input) }

      it "returns zero" do
        expect(resolver.turn_order_delay).to eq(0.0)
      end
    end

    context "with multiple mechanisms" do
      let(:cartridge_a) { create(:cartridge_85mm, player:) }
      let(:cartridge_b) { create(:cartridge_85mm, player:) }

      let(:runtime_a) { cartridge_a.to_runtime(match:, random_seed:) }
      let(:runtime_b) { cartridge_b.to_runtime(match:, random_seed: random_seed + 1) }

      let(:resolver) { described_class.new([runtime_a, runtime_b], player_input) }

      it "sums delays from all runtimes" do
        # Both cartridges return 0.0 delay
        expect(resolver.turn_order_delay).to eq(0.0)
      end
    end
  end

  describe "#ui_metadata" do
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
    let(:player_input) { {} }
    let(:resolver) { described_class.new([runtime], player_input) }

    it "collects metadata from all runtimes" do
      metadata = resolver.ui_metadata

      expect(metadata).to be_an(Array)
      expect(metadata.first).to include(:slot)
      expect(metadata.first).to include(:control_type)
      expect(metadata.first).to include(:input_key)
    end

    it "rejects empty metadata" do
      empty_runtime = double(
        "EmptyRuntime",
        metadata: {}
      )
      resolver = described_class.new([runtime, empty_runtime], player_input)

      metadata = resolver.ui_metadata

      expect(metadata.length).to eq(1)
    end
  end

  describe "#assistance_data" do
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
    let(:player_input) { {} }

    context "with no assistance runtimes" do
      let(:resolver) { described_class.new([runtime], player_input) }

      it "returns empty hash" do
        expect(resolver.assistance_data).to eq({})
      end
    end
  end

  describe "#engine_affectors" do
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
    let(:player_input) { {} }

    context "with no affector runtimes" do
      let(:resolver) { described_class.new([runtime], player_input) }

      it "returns empty array" do
        expect(resolver.engine_affectors).to eq([])
      end
    end

    context "with affector runtimes" do
      let(:wind_affector) { double("WindAffector") }
      let(:runtime_with_affector) do
        double(
          "RuntimeWithAffector",
          affectors: [wind_affector]
        )
      end
      let(:resolver) { described_class.new([runtime, runtime_with_affector], player_input) }

      it "collects affectors from all runtimes" do
        affectors = resolver.engine_affectors

        expect(affectors).to include(wind_affector)
      end
    end
  end

  describe "#engine_hooks" do
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:runtime) { cartridge.to_runtime(match:, random_seed:) }
    let(:player_input) { {} }

    context "with no hook runtimes" do
      let(:resolver) { described_class.new([runtime], player_input) }

      it "returns empty array" do
        expect(resolver.engine_hooks).to eq([])
      end
    end

    context "with hook runtimes" do
      let(:parachute_hook) { double("ParachuteHook") }
      let(:runtime_with_hook) do
        double(
          "RuntimeWithHook",
          hooks: [parachute_hook]
        )
      end
      let(:resolver) { described_class.new([runtime, runtime_with_hook], player_input) }

      it "collects hooks from all runtimes" do
        hooks = resolver.engine_hooks

        expect(hooks).to include(parachute_hook)
      end
    end
  end
end
