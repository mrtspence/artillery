# frozen_string_literal: true

require "test_helper"

RSpec.describe PlayerMechanisms::Edwardian::Cartridge85mm, type: :model do
  describe "#runtime_class" do
    let(:cartridge) { build(:cartridge_85mm) }

    it "returns Cartridge85mmRuntime class" do
      expect(cartridge.runtime_class).to eq(Artillery::Mechanisms::Runtimes::Cartridge85mmRuntime)
    end
  end

  describe "#input_keys" do
    let(:cartridge) { build(:cartridge_85mm) }

    it "returns powder_charges input" do
      expect(cartridge.input_keys).to eq([:powder_charges])
    end
  end

  describe "#output_keys" do
    let(:cartridge) { build(:cartridge_85mm) }

    it "returns ballistic output keys" do
      expect(cartridge.output_keys).to contain_exactly(
        :base_initial_velocity,
        :shell_weight,
        :surface_area,
        :caliber_mm
      )
    end
  end

  describe "#priority" do
    context "with default priority" do
      let(:cartridge) { build(:cartridge_85mm) }

      it "returns priority 10" do
        expect(cartridge.priority).to eq(10)
      end
    end

    context "with custom priority in modifiers" do
      let(:cartridge) { build(:cartridge_85mm, modifiers: { 'priority' => 15 }) }

      it "returns custom priority" do
        expect(cartridge.priority).to eq(15)
      end
    end
  end

  describe "#to_runtime" do
    let(:player) { create(:player) }
    let(:cartridge) { create(:cartridge_85mm, player: player) }
    let(:match) { double("Match", id: 1) }
    let(:random_seed) { 12345 }

    it "creates a Cartridge85mmRuntime instance" do
      runtime = cartridge.to_runtime(match: match, random_seed: random_seed)

      expect(runtime).to be_a(Artillery::Mechanisms::Runtimes::Cartridge85mmRuntime)
      expect(runtime.mechanism).to eq(cartridge)
      expect(runtime.match).to eq(match)
    end

    it "initializes variance values" do
      runtime = cartridge.to_runtime(match: match, random_seed: random_seed)

      expect(runtime.velocity_variance).to be_between(0.95, 1.05)
      expect(runtime.weight_variance).to be_between(0.98, 1.02)
    end
  end

  describe "factory traits" do
    describe ":upgraded" do
      let(:cartridge) { build(:cartridge_85mm, :upgraded) }

      it "has higher upgrade level" do
        expect(cartridge.upgrade_level).to eq(2)
      end

      it "has improved velocity characteristics" do
        expect(cartridge.modifiers['base_velocity']).to eq(420)
        expect(cartridge.modifiers['charge_velocity_per_unit']).to eq(55)
      end
    end

    describe ":composite_shell" do
      let(:cartridge) { build(:cartridge_85mm, :composite_shell) }

      it "has lighter shell weight" do
        expect(cartridge.modifiers['shell_weight_kg']).to eq(7.8)
      end

      it "has composite construction" do
        expect(cartridge.modifiers['construction']).to eq('composite')
      end
    end

    describe ":high_velocity" do
      let(:cartridge) { build(:cartridge_85mm, :high_velocity) }

      it "has higher base cost" do
        expect(cartridge.base_cost).to eq(200.0)
      end

      it "has improved velocity characteristics" do
        expect(cartridge.modifiers['base_velocity']).to eq(450)
        expect(cartridge.modifiers['charge_velocity_per_unit']).to eq(60)
      end
    end
  end
end
