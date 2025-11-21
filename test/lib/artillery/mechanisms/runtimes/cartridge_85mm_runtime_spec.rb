# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Mechanisms::Runtimes::Cartridge85mmRuntime do
  let(:player) { create(:player) }
  let(:cartridge) { create(:cartridge_85mm, player:) }
  let(:match) { double("Match", id: 1) }
  let(:random_seed) { 12345 }

  subject(:runtime) { cartridge.to_runtime(match:, random_seed:) }

  describe "#resolve" do
    context "with valid inputs" do
      let(:context) { { powder_charges: 3 } }

      it "calculates base_initial_velocity from powder charges" do
        result = runtime.resolve(context)

        # Base: 400 + (3 * 50) = 550 m/s, with variance
        expect(result[:base_initial_velocity]).to be_between(522.5, 577.5)
      end

      it "applies weight variance to shell weight" do
        result = runtime.resolve(context)

        # Base: 8.4 kg with ±2% variance
        expect(result[:shell_weight]).to be_between(8.232, 8.568)
      end

      it "calculates surface area from caliber" do
        result = runtime.resolve(context)

        caliber_m = 84.5 / 1000.0
        expected_area = Math::PI * (caliber_m / 2) ** 2

        expect(result[:surface_area]).to be_within(0.0001).of(expected_area)
      end

      it "includes caliber_mm in output" do
        result = runtime.resolve(context)

        expect(result[:caliber_mm]).to eq(84.5)
      end
    end

    context "with default powder charge" do
      let(:context) { {} }

      it "uses default of 1 charge" do
        result = runtime.resolve(context)

        # Base: 400 + (1 * 50) = 450 m/s, with variance
        expect(result[:base_initial_velocity]).to be_between(427.5, 472.5)
      end
    end

    context "with minimum powder charges" do
      let(:context) { { powder_charges: 1 } }

      it "calculates velocity with minimum charges" do
        result = runtime.resolve(context)

        # Base: 400 + (1 * 50) = 450 m/s
        expect(result[:base_initial_velocity]).to be_between(427.5, 472.5)
      end
    end

    context "with maximum powder charges" do
      let(:context) { { powder_charges: 5 } }

      it "calculates velocity with maximum charges" do
        result = runtime.resolve(context)

        # Base: 400 + (5 * 50) = 650 m/s
        expect(result[:base_initial_velocity]).to be_between(617.5, 682.5)
      end
    end

    context "with custom modifiers" do
      let(:cartridge) do
        create(
          :cartridge_85mm,
          player:,
          modifiers: {
            'base_velocity' => 500,
            'charge_velocity_per_unit' => 60,
            'shell_weight_kg' => 10.0,
            'caliber_mm' => 90.0
          }
        )
      end
      let(:context) { { powder_charges: 2 } }

      it "uses custom base velocity" do
        result = runtime.resolve(context)

        # Base: 500 + (2 * 60) = 620 m/s
        expect(result[:base_initial_velocity]).to be_between(589, 651)
      end

      it "uses custom shell weight" do
        result = runtime.resolve(context)

        # Base: 10.0 kg with ±2% variance
        expect(result[:shell_weight]).to be_between(9.8, 10.2)
      end

      it "uses custom caliber" do
        result = runtime.resolve(context)

        expect(result[:caliber_mm]).to eq(90.0)
      end
    end
  end

  describe "#metadata" do
    it "returns UI control metadata" do
      metadata = runtime.metadata

      expect(metadata).to include(
        slot: :cartridge,
        control_type: :slider,
        input_key: :powder_charges,
        label: "Powder Charges"
      )
    end

    it "specifies valid range for powder charges" do
      metadata = runtime.metadata

      expect(metadata[:min]).to eq(1)
      expect(metadata[:max]).to eq(5)
      expect(metadata[:step]).to eq(1)
    end

    it "provides default value" do
      metadata = runtime.metadata

      expect(metadata[:default]).to eq(2)
    end

    it "includes unit label" do
      metadata = runtime.metadata

      expect(metadata[:unit]).to eq("charges")
    end
  end

  describe "#turn_order_delay" do
    it "returns zero by default" do
      expect(runtime.turn_order_delay).to eq(0.0)
    end
  end

  describe "#affectors" do
    it "returns empty array by default" do
      expect(runtime.affectors).to eq([])
    end
  end

  describe "#hooks" do
    it "returns empty array by default" do
      expect(runtime.hooks).to eq([])
    end
  end

  describe "factory traits" do
    describe ":upgraded cartridge" do
      let(:cartridge) { create(:cartridge_85mm, :upgraded, player:) }
      let(:context) { { powder_charges: 3 } }

      it "produces higher velocities" do
        result = runtime.resolve(context)

        # Upgraded: 420 + (3 * 55) = 585 m/s (vs standard 550)
        expect(result[:base_initial_velocity]).to be > 555
      end
    end

    describe ":composite_shell cartridge" do
      let(:cartridge) { create(:cartridge_85mm, :composite_shell, player:) }
      let(:context) { { powder_charges: 3 } }

      it "produces lighter shells" do
        result = runtime.resolve(context)

        # Composite: 7.8 kg (vs standard 8.4)
        expect(result[:shell_weight]).to be < 8.0
      end
    end

    describe ":high_velocity cartridge" do
      let(:cartridge) { create(:cartridge_85mm, :high_velocity, player:) }
      let(:context) { { powder_charges: 3 } }

      it "produces significantly higher velocities" do
        result = runtime.resolve(context)

        # High velocity: 450 + (3 * 60) = 630 m/s (vs standard 550)
        expect(result[:base_initial_velocity]).to be > 598
      end
    end
  end
end
