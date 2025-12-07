# frozen_string_literal: true

FactoryBot.define do
  factory :player_loadout do
    association :player
    sequence(:label) { |n| "Loadout #{n}" }
    engine_type { 'Ballistic3D' }
    platform_type { 'QF18Pounder' }
    default { false }

    # Trait for default loadout
    trait :default do
      default { true }
      label { "Default Configuration" }
    end

    # Trait for heavy loadout
    trait :heavy do
      label { "Heavy Artillery" }
    end

    # Trait for precision loadout
    trait :precision do
      label { "Precision Shot" }
    end

    # Trait for complete QF 18-pounder with all required mechanisms
    trait :qf_18_pounder_complete do
      platform_type { "qf_18_pounder" }

      after(:create) do |loadout|
        # Create and attach all required mechanisms
        elevation = FactoryBot.create(:elevation_dial, player: loadout.player)
        deflection = FactoryBot.create(:deflection_screw, player: loadout.player)
        cartridge = FactoryBot.create(:cartridge_85mm, player: loadout.player)
        barrel = FactoryBot.create(:barrel_85mm, player: loadout.player)
        breech = FactoryBot.create(:breech_qf, player: loadout.player)
        recoil = FactoryBot.create(:recoil_system, player: loadout.player)
        sight = FactoryBot.create(:optical_sight, player: loadout.player)

        # Create slots
        [elevation, deflection, cartridge, barrel, breech, recoil, sight].each do |mech|
          FactoryBot.create(:player_loadout_slot,
            player_loadout: loadout,
            player_mechanism: mech,
            slot_key: mech.slot_key
          )
        end

        loadout.reload
      end
    end
  end
end
