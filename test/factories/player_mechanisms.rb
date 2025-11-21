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
    factory :cartridge_85mm, class: 'PlayerMechanisms::Cartridge85mm' do
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
  end
end
