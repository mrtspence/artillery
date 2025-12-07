# frozen_string_literal: true

require "test_helper"

RSpec.describe "Mechanism Runtime Validation" do
  let(:player) { create(:player) }
  let(:match) { double("Match", id: 1) }
  let(:random_seed) { 12345 }

  describe "Cartridge85mmRuntime" do
    it "raises error when construction modifier is missing" do
      cartridge = create(
        :cartridge_85mm,
        player:,
        modifiers: {
          'shell_weight_kg' => 8.4,
          'charge_velocity_per_unit' => 50,
          'base_velocity' => 400,
          'caliber_mm' => 84.5
          # Missing: 'construction'
        }
      )

      expect {
        cartridge.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*construction/i)
    end
  end

  describe "Barrel85mmRuntime" do
    it "raises error when construction modifier is missing" do
      barrel = create(
        :barrel_85mm,
        player:,
        modifiers: {
          'length_meters' => 2.5,
          'wear_factor' => 1.0
          # Missing: 'construction'
        }
      )

      expect {
        barrel.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*construction/i)
    end
  end

  describe "BreechQfRuntime" do
    it "raises error when breech_type modifier is missing" do
      breech = create(
        :breech_qf,
        player:,
        modifiers: {
          'base_loading_time' => 3.0
          # Missing: 'breech_type'
        }
      )

      expect {
        breech.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*breech_type/i)
    end
  end

  describe "DeflectionScrewRuntime" do
    it "raises error when thread_pitch modifier is missing" do
      deflection = create(
        :deflection_screw,
        player:,
        modifiers: {
          'degrees_per_turn' => 0.5,
          'max_deflection' => 8
          # Missing: 'thread_pitch'
        }
      )

      expect {
        deflection.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*thread_pitch/i)
    end
  end

  describe "ElevationDialRuntime" do
    it "raises error when graduations modifier is missing" do
      elevation = create(
        :elevation_dial,
        player:,
        modifiers: {
          'degrees_per_click' => 1.0,
          'max_elevation' => 45,
          'min_elevation' => 5
          # Missing: 'graduations'
        }
      )

      expect {
        elevation.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*graduations/i)
    end
  end

  describe "RecoilSystemRuntime" do
    it "raises error when recoil_type modifier is missing" do
      recoil = create(
        :recoil_system,
        player:,
        modifiers: {
          'recovery_time_base' => 2.0,
          'accuracy_penalty' => 0.3
          # Missing: 'recoil_type'
        }
      )

      expect {
        recoil.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*recoil_type/i)
    end
  end

  describe "OpticalSightRuntime" do
    it "raises error when sight_type modifier is missing" do
      sight = create(
        :optical_sight,
        player:,
        modifiers: {
          'magnification' => 1.0
          # Missing: 'sight_type'
        }
      )

      expect {
        sight.to_runtime(match:, random_seed:)
      }.to raise_error(ArgumentError, /missing required modifiers.*sight_type/i)
    end
  end
end
