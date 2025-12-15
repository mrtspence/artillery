# frozen_string_literal: true

FactoryBot.define do
  # Base PlayerMechanism factory
  factory :player_mechanism do
    association :player
    slot_key { :generic }
    upgrade_level { 0 }
    modifiers { {} }
    base_cost { 100.0 }
    base_weight { 50.0 }
    priority { 50 }

    # Cartridge85mm factory
    factory :cartridge_85mm, class: 'PlayerMechanisms::Edwardian::Cartridge85mm' do
      slot_key { :cartridge }
      priority { 10 }
      base_cost { 150.0 }
      base_weight { 8.5 }
      modifiers do
        {
          'shell_weight_kg' => 8.4,
          'charge_velocity_per_unit' => 50,
          'base_velocity' => 400,
          'caliber_mm' => 84.5,
          'construction' => 'steel'
        }
      end

      # Trait for upgraded cartridge
      trait :upgraded do
        upgrade_level { 2 }
        modifiers do
          {
            'shell_weight_kg' => 8.4,
            'charge_velocity_per_unit' => 55,
            'base_velocity' => 420,
            'caliber_mm' => 84.5,
            'construction' => 'steel'
          }
        end
      end

      # Trait for composite shell construction
      trait :composite_shell do
        modifiers do
          {
            'shell_weight_kg' => 7.8,
            'charge_velocity_per_unit' => 50,
            'base_velocity' => 400,
            'caliber_mm' => 84.5,
            'construction' => 'composite'
          }
        end
      end

      # Trait for high velocity variant
      trait :high_velocity do
        base_cost { 200.0 }
        modifiers do
          {
            'shell_weight_kg' => 8.4,
            'charge_velocity_per_unit' => 60,
            'base_velocity' => 450,
            'caliber_mm' => 84.5,
            'construction' => 'steel'
          }
        end
      end
    end

    # Barrel85mm factory
    factory :barrel_85mm, class: 'PlayerMechanisms::Edwardian::Barrel85mm' do
      slot_key { :barrel }
      priority { 15 }
      base_cost { 500.0 }
      base_weight { 120.0 }
      modifiers do
        {
          'length_meters' => 2.5,
          'construction' => 'steel',
          'wear_factor' => 1.0,
          'velocity_multiplier' => 1.0
        }
      end

      trait :chrome_lined do
        modifiers do
          {
            'length_meters' => 2.5,
            'construction' => 'chrome_lined',
            'wear_factor' => 1.0,
            'velocity_multiplier' => 1.05
          }
        end
      end

      trait :lightweight do
        base_weight { 90.0 }
        modifiers do
          {
            'length_meters' => 2.0,
            'construction' => 'lightweight',
            'wear_factor' => 1.0,
            'velocity_multiplier' => 0.95
          }
        end
      end
    end

    # BreechQf factory
    factory :breech_qf, class: 'PlayerMechanisms::Edwardian::BreechQf' do
      slot_key { :breech }
      priority { 90 }
      base_cost { 400.0 }
      base_weight { 45.0 }
      modifiers do
        {
          'breech_type' => 'interrupted_screw',
          'base_loading_time' => 3.0
        }
      end

      trait :sliding_block do
        modifiers do
          {
            'breech_type' => 'sliding_block',
            'base_loading_time' => 2.5
          }
        end
      end
    end

    # DeflectionScrew factory
    factory :deflection_screw, class: 'PlayerMechanisms::Edwardian::DeflectionScrew' do
      slot_key { :deflection }
      priority { 5 }
      base_cost { 200.0 }
      base_weight { 15.0 }
      modifiers do
        {
          'degrees_per_turn' => 0.5,
          'max_deflection' => 8,
          'thread_pitch' => 'standard'
        }
      end

      trait :fine_pitch do
        modifiers do
          {
            'degrees_per_turn' => 0.25,
            'max_deflection' => 8,
            'thread_pitch' => 'fine'
          }
        end
      end
    end

    # ElevationDial factory
    factory :elevation_dial, class: 'PlayerMechanisms::Edwardian::ElevationDial' do
      slot_key { :elevation }
      priority { 5 }
      base_cost { 300.0 }
      base_weight { 20.0 }
      modifiers do
        {
          'graduations' => 'standard',
          'degrees_per_click' => 1.0,
          'max_elevation' => 45,
          'min_elevation' => 5
        }
      end

      trait :fine_graduations do
        modifiers do
          {
            'graduations' => 'fine',
            'degrees_per_click' => 0.5,
            'max_elevation' => 45,
            'min_elevation' => 5
          }
        end
      end

      trait :vernier do
        base_cost { 450.0 }
        modifiers do
          {
            'graduations' => 'vernier',
            'degrees_per_click' => 0.1,
            'max_elevation' => 45,
            'min_elevation' => 5
          }
        end
      end
    end

    # RecoilSystem factory
    factory :recoil_system, class: 'PlayerMechanisms::Edwardian::RecoilSystem' do
      slot_key { :recoil_system }
      priority { 85 }
      base_cost { 600.0 }
      base_weight { 80.0 }
      modifiers do
        {
          'recoil_type' => 'standard',
          'recovery_time_base' => 2.0,
          'accuracy_penalty' => 0.3
        }
      end

      trait :hydropneumatic do
        base_cost { 900.0 }
        modifiers do
          {
            'recoil_type' => 'hydropneumatic',
            'recovery_time_base' => 1.5,
            'accuracy_penalty' => 0.2
          }
        end
      end
    end

    # OpticalSight factory
    factory :optical_sight, class: 'PlayerMechanisms::Edwardian::OpticalSight' do
      slot_key { :sight }
      priority { 95 }
      base_cost { 250.0 }
      base_weight { 5.0 }
      modifiers do
        {
          'sight_type' => 'iron',
          'accuracy_bonus' => 0.5,
          'magnification' => 1.0
        }
      end

      trait :telescopic do
        base_cost { 400.0 }
        modifiers do
          {
            'sight_type' => 'telescopic',
            'accuracy_bonus' => 0.75,
            'magnification' => 4.0
          }
        end
      end

      trait :range_finder do
        base_cost { 700.0 }
        modifiers do
          {
            'sight_type' => 'range_finder',
            'accuracy_bonus' => 0.9,
            'magnification' => 6.0
          }
        end
      end
    end
  end
end
