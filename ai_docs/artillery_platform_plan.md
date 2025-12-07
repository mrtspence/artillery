# Artillery Platform Implementation Plan

**Date:** 2025-12-06
**Status:** Design & Implementation Plan
**Context:** Following successful implementation of mechanism pipeline system with PipelineTransform/PipelineContext

---

## Executive Summary

This document outlines the implementation plan for **Artillery Platforms** - predefined artillery pieces (like the QF 18-pounder) that constrain which mechanisms players can use while allowing customization within those constraints. Platforms define the identity and balance of different artillery systems while maintaining player agency through mechanism selection and upgrades.

---

## Problem Statement

### Current System (What We Have)

✅ **Mechanisms**: 7 distinct mechanism types implemented
- Cartridge85mm, Barrel85mm, BreechQf, DeflectionScrew, ElevationDial, RecoilSystem, OpticalSight
- Each has modifiers, upgrades, and contributes to ballistic pipeline
- Validation ensures required modifiers are present
- Per-match randomization with deterministic seeds

✅ **PlayerLoadout**: Players can create named loadouts
- Contains `platform_type` field (string) - currently unconstrained
- Mechanisms added via PlayerLoadoutSlots
- Can instantiate runtimes for match

❌ **What's Missing**: Platform Definitions & Constraints
- No enforcement of which mechanisms belong to which platform
- No validation that a loadout's mechanisms are compatible
- No concept of mechanism compatibility/substitutability
- Players could theoretically mix incompatible components (e.g., wrong caliber barrel)

### Desired State

A **Platform** is a template that defines:
1. **Identity**: Name, description, historical context, engine type
2. **Required Slot Structure**: Which mechanism slots MUST be filled
3. **Allowed Mechanisms Per Slot**: Compatibility rules (e.g., only 85mm barrels on QF 18-pounder)
4. **Balance Parameters**: Base stats, restrictions, special rules

### Key Design Goals

1. **Distinct Platform Identity**: Each platform feels different to play
2. **Constrained Customization**: Players customize within platform rules, not arbitrarily
3. **Upgrade Paths**: Multiple mechanism options per slot (standard vs upgraded variants)
4. **Balance Control**: Game designer can control what combinations are legal
5. **Extensibility**: Easy to add new platforms without rewriting mechanism system
6. **Backward Compatibility**: Works with existing mechanism/loadout models

---

## Architecture Design

### Core Concept: Platform as Constraint Definition

A **Platform** is NOT a database model of a specific artillery piece. Instead, it's a **configuration/constraint object** that:
- Defines rules for what makes a valid loadout for that platform
- Lives in code (Ruby classes) or configuration (YAML), NOT the database
- Can be instantiated to validate loadouts or seed initial player configurations

### Why Not Database Tables?

**Rejected Approach:** `create_table :artillery_platforms`

Platforms are **game design artifacts**, not player data. They:
- Change with game updates/balancing (code deployment, not migrations)
- Have complex validation logic best expressed in Ruby
- Don't need CRUD operations (players don't create platforms)
- Are better versioned in Git than database rows

**Comparison:**
- ✅ **In Code**: Change platform rules → deploy code → instant update for all players
- ❌ **In Database**: Change platform rules → write migration → deploy → run migration → hope nothing breaks

### Data Model

```
┌─────────────────────────────────────────────────────────┐
│                    CODE (NOT DATABASE)                  │
│                                                         │
│  Artillery::Platforms::Qf18Pounder                     │
│    - slot_requirements                                 │
│    - allowed_mechanisms_per_slot                       │
│    - validation_rules                                  │
│    - base_characteristics                              │
└─────────────────────────────────────────────────────────┘
                          ↓
                    validates
                          ↓
┌─────────────────────────────────────────────────────────┐
│              DATABASE: player_loadouts                  │
│                                                         │
│  platform_type: "qf_18_pounder"  ← string reference    │
│  label: "My Custom QF Setup"                           │
│  player_id: 42                                         │
└─────┬───────────────────────────────────────────────────┘
      │
      │ has_many (through player_loadout_slots)
      ↓
┌─────────────────────────────────────────────────────────┐
│           DATABASE: player_mechanisms                   │
│                                                         │
│  type: "PlayerMechanisms::Barrel85mm"                  │
│  slot_key: "barrel"                                    │
│  modifiers: { length_meters: 2.5, ... }                │
└─────────────────────────────────────────────────────────┘
```

### Platform Registry Pattern

```ruby
# lib/artillery/platforms/registry.rb
module Artillery
  module Platforms
    class Registry
      @platforms = {}

      class << self
        def register(key, platform_class)
          @platforms[key.to_s] = platform_class
        end

        def get(key)
          @platforms[key.to_s] or raise UnknownPlatformError, key
        end

        def all
          @platforms.values
        end

        def all_keys
          @platforms.keys
        end
      end
    end
  end
end
```

### Base Platform Class

```ruby
# lib/artillery/platforms/base.rb
module Artillery
  module Platforms
    class Base
      class << self
        # Platform metadata
        def key
          raise NotImplementedError
        end

        def name
          raise NotImplementedError
        end

        def description
          raise NotImplementedError
        end

        def engine_type
          "ballistic_3d"  # Default, can override
        end

        # Slot structure definition
        # Returns hash: { slot_key => { required: bool, allowed_types: [...] } }
        def slot_requirements
          raise NotImplementedError
        end

        # Validation: is this mechanism allowed in this slot?
        # @param slot_key [Symbol] The slot being filled
        # @param mechanism [PlayerMechanism] The mechanism to validate
        # @return [Boolean]
        def mechanism_allowed_in_slot?(slot_key, mechanism)
          requirements = slot_requirements[slot_key.to_sym]
          return false unless requirements

          allowed_types = requirements[:allowed_types]
          allowed_types.include?(mechanism.class.name)
        end

        # Validation: does this loadout satisfy platform requirements?
        # @param loadout [PlayerLoadout] The loadout to validate
        # @return [Array<String>] Array of error messages (empty if valid)
        def validate_loadout(loadout)
          errors = []

          # Check platform type matches
          unless loadout.platform_type == key
            errors << "Loadout platform_type must be '#{key}'"
            return errors
          end

          # Check required slots are filled
          slot_requirements.each do |slot_key, requirements|
            next unless requirements[:required]

            mechanism_in_slot = loadout.player_mechanisms.find { |m| m.slot_key == slot_key.to_s }
            unless mechanism_in_slot
              errors << "Required slot '#{slot_key}' is not filled"
              next
            end

            # Check mechanism type is allowed
            unless mechanism_allowed_in_slot?(slot_key, mechanism_in_slot)
              errors << "Mechanism #{mechanism_in_slot.class.name} is not allowed in slot '#{slot_key}'"
            end
          end

          # Check for extra slots not defined in platform
          defined_slots = slot_requirements.keys.map(&:to_s)
          extra_slots = loadout.player_mechanisms.map(&:slot_key).uniq - defined_slots
          if extra_slots.any?
            errors << "Loadout contains undefined slots: #{extra_slots.join(', ')}"
          end

          errors
        end

        # Additional constraints (can be overridden by platforms)
        # @param loadout [PlayerLoadout]
        # @return [Array<String>] Additional errors
        def validate_additional_constraints(loadout)
          []  # Override in subclasses for platform-specific rules
        end
      end
    end
  end
end
```

---

## Example Platform: QF 18-Pounder

### Implementation

```ruby
# lib/artillery/platforms/qf_18_pounder.rb
module Artillery
  module Platforms
    class Qf18Pounder < Base
      class << self
        def key
          "qf_18_pounder"
        end

        def name
          "Ordnance QF 18-pounder"
        end

        def description
          "British field gun of the early 20th century. Quick-firing breech, "\
          "accurate deflection control, and reliable recoil system. "\
          "Edwardian-era technology."
        end

        def historical_period
          "1904-1945"
        end

        def caliber
          "84mm" # Actually 83.8mm, but we use 85mm in game
        end

        # Define required slots and what mechanisms can fill them
        def slot_requirements
          {
            # Aiming mechanisms (required)
            elevation: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::ElevationDial"
              ],
              description: "Vertical aiming mechanism (dial or quadrant)"
            },

            deflection: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::DeflectionScrew"
              ],
              description: "Horizontal aiming mechanism (screw or wheel)"
            },

            # Core ballistic components (required)
            cartridge: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::Cartridge85mm"
              ],
              description: "Ammunition type - must be 85mm caliber"
            },

            barrel: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::Barrel85mm"
              ],
              description: "Gun barrel - must be 85mm caliber"
            },

            # Mechanical systems (required)
            breech: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::BreechQf"
              ],
              description: "Quick-firing breech mechanism"
            },

            recoil_system: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::RecoilSystem"
              ],
              description: "Hydro-pneumatic or spring recoil system"
            },

            # Sighting (required for this platform)
            sight: {
              required: true,
              allowed_types: [
                "PlayerMechanisms::OpticalSight"
              ],
              description: "Telescopic or iron sights"
            }
          }
        end

        # Platform-specific constraints
        def validate_additional_constraints(loadout)
          errors = []

          # Example: QF 18-pounder requires barrel length between 2.0-2.8m
          barrel = loadout.player_mechanisms.find { |m| m.slot_key == "barrel" }
          if barrel && barrel.modifiers["length_meters"]
            length = barrel.modifiers["length_meters"]
            unless length.between?(2.0, 2.8)
              errors << "QF 18-pounder barrel length must be between 2.0m and 2.8m (got #{length}m)"
            end
          end

          # Example: Cartridge and barrel must have compatible caliber
          cartridge = loadout.player_mechanisms.find { |m| m.slot_key == "cartridge" }
          if cartridge && barrel
            cartridge_caliber = cartridge.modifiers["caliber_mm"]
            barrel_caliber = barrel.class.name.match(/(\d+)mm/)[1].to_f rescue nil

            if cartridge_caliber && barrel_caliber && (cartridge_caliber - barrel_caliber).abs > 1
              errors << "Cartridge caliber (#{cartridge_caliber}mm) does not match barrel caliber (#{barrel_caliber}mm)"
            end
          end

          errors
        end

        # Platform characteristics (for UI display, balance info)
        def characteristics
          {
            era: "Edwardian",
            country: "United Kingdom",
            role: "Field Artillery",
            crew_size: 5,
            rate_of_fire: "20 rounds/min (theoretical)",
            max_range_meters: 6525,
            shell_weight_kg_range: [8.1, 8.5],
            muzzle_velocity_range: [492, 502], # m/s
            weight_kg: 1282 # Gun + carriage
          }
        end
      end
    end

    # Register platform
    Registry.register(:qf_18_pounder, Qf18Pounder)
  end
end
```

---

## Integration with Existing Models

### PlayerLoadout Validation

```ruby
# app/models/player_loadout.rb
class PlayerLoadout < ApplicationRecord
  # ... existing code ...

  validate :platform_requirements_met
  validate :platform_specific_constraints

  private

  def platform_requirements_met
    return unless platform_type.present?

    platform = Artillery::Platforms::Registry.get(platform_type)
    validation_errors = platform.validate_loadout(self)

    validation_errors.each do |error|
      errors.add(:base, error)
    end
  end

  def platform_specific_constraints
    return unless platform_type.present?

    platform = Artillery::Platforms::Registry.get(platform_type)
    additional_errors = platform.validate_additional_constraints(self)

    additional_errors.each do |error|
      errors.add(:base, error)
    end
  end
end
```

### PlayerLoadout Helper Methods

```ruby
# app/models/player_loadout.rb
class PlayerLoadout < ApplicationRecord
  # ... existing code ...

  # Get the platform definition object
  def platform
    @platform ||= Artillery::Platforms::Registry.get(platform_type)
  end

  # Get unfilled required slots
  def missing_required_slots
    return [] unless platform_type.present?

    filled_slots = player_mechanisms.map(&:slot_key)
    platform.slot_requirements
      .select { |_, reqs| reqs[:required] }
      .keys
      .map(&:to_s)
      .reject { |slot| filled_slots.include?(slot) }
  end

  # Check if loadout is complete and valid
  def valid_for_match?
    valid? && missing_required_slots.empty?
  end

  # Get allowed mechanism types for a slot
  def allowed_mechanism_types_for_slot(slot_key)
    return [] unless platform_type.present?

    requirements = platform.slot_requirements[slot_key.to_sym]
    requirements ? requirements[:allowed_types] : []
  end
end
```

---

## Future Platforms (Examples)

### Heavy Howitzer Platform

```ruby
# lib/artillery/platforms/heavy_howitzer_155mm.rb
module Artillery
  module Platforms
    class HeavyHowitzer155mm < Base
      def self.key
        "heavy_howitzer_155mm"
      end

      def self.name
        "155mm Heavy Howitzer"
      end

      def self.description
        "Modern heavy howitzer with high-angle capability. "\
        "Larger caliber, longer range, slower rate of fire."
      end

      def self.slot_requirements
        {
          elevation: {
            required: true,
            allowed_types: [
              "PlayerMechanisms::ElevationDial",
              "PlayerMechanisms::ElevationQuadrant" # Future: different aiming mechanism
            ]
          },
          # ... 155mm-specific mechanisms
          cartridge: {
            required: true,
            allowed_types: [
              "PlayerMechanisms::Cartridge155mm" # Future: different caliber
            ]
          },
          # ... etc
        }
      end

      def self.characteristics
        {
          era: "Modern",
          caliber: "155mm",
          max_range_meters: 24000,
          shell_weight_kg_range: [45, 48],
          rate_of_fire: "4 rounds/min",
          crew_size: 8
        }
      end
    end

    Registry.register(:heavy_howitzer_155mm, HeavyHowitzer155mm)
  end
end
```

### Mortar Platform (Different Mechanics)

```ruby
# lib/artillery/platforms/mortar_81mm.rb
module Artillery
  module Platforms
    class Mortar81mm < Base
      def self.key
        "mortar_81mm"
      end

      def self.slot_requirements
        {
          # Mortars use different aiming system (no deflection screw)
          elevation: {
            required: true,
            allowed_types: [
              "PlayerMechanisms::MortarBipod" # Future: mortar-specific
            ]
          },
          # No breech (muzzle-loading)
          # Different ballistic properties (high arc only)
        }
      end

      def self.validate_additional_constraints(loadout)
        errors = []

        # Mortars require minimum elevation angle
        elevation_mech = loadout.player_mechanisms.find { |m| m.slot_key == "elevation" }
        if elevation_mech && elevation_mech.modifiers["min_elevation"]
          min_elev = elevation_mech.modifiers["min_elevation"]
          unless min_elev >= 45
            errors << "Mortar minimum elevation must be at least 45 degrees"
          end
        end

        errors
      end
    end

    Registry.register(:mortar_81mm, Mortar81mm)
  end
end
```

---

## Implementation Phases

### Phase 1: Core Platform System (Immediate)

**Files to Create:**
1. `lib/artillery/platforms/registry.rb` - Platform registry singleton
2. `lib/artillery/platforms/base.rb` - Base platform class
3. `lib/artillery/platforms/qf_18_pounder.rb` - First concrete platform
4. `lib/artillery/platforms/errors.rb` - Custom error classes

**Files to Modify:**
1. `app/models/player_loadout.rb` - Add platform validation
2. `config/initializers/zeitwerk_lib.rb` - Ensure platforms autoload
3. Add platform validations to PlayerLoadout tests

**Tests to Create:**
1. `test/lib/artillery/platforms/registry_spec.rb`
2. `test/lib/artillery/platforms/qf_18_pounder_spec.rb`
3. `test/models/player_loadout_platform_validation_spec.rb`

### Phase 2: Platform-Aware Loadout Builder (Next)

**Features:**
- UI component to show platform requirements when creating loadout
- Display allowed mechanism types per slot
- Show which slots are filled/missing
- Validation feedback before save

**Files to Create:**
1. `app/helpers/platform_helper.rb` - Platform display helpers
2. Platform selection UI components
3. Mechanism compatibility indicator in loadout builder

### Phase 3: Additional Platforms (Future)

**Approach:**
- Add new platform classes as needed
- Each platform is independent Ruby class
- Register in Registry
- No database migrations needed (unless new mechanism types required)

**Examples:**
1. `lib/artillery/platforms/french_75mm.rb` - Famous French gun
2. `lib/artillery/platforms/german_105mm.rb` - German howitzer
3. `lib/artillery/platforms/naval_gun_12_inch.rb` - Naval artillery

### Phase 4: Platform Seeding & Defaults (Future)

**Features:**
- Seed default platform-compatible loadouts for new players
- "Standard QF 18-pounder" starter loadout
- Tutorial loadouts that teach platform mechanics

---

## Testing Strategy

### Unit Tests: Platform Classes

```ruby
# test/lib/artillery/platforms/qf_18_pounder_spec.rb
RSpec.describe Artillery::Platforms::Qf18Pounder do
  describe ".key" do
    it "returns platform key" do
      expect(described_class.key).to eq("qf_18_pounder")
    end
  end

  describe ".slot_requirements" do
    it "defines all required slots" do
      requirements = described_class.slot_requirements

      expect(requirements.keys).to include(
        :elevation, :deflection, :cartridge, :barrel,
        :breech, :recoil_system, :sight
      )
    end

    it "marks critical slots as required" do
      requirements = described_class.slot_requirements

      expect(requirements[:elevation][:required]).to be true
      expect(requirements[:barrel][:required]).to be true
    end

    it "specifies allowed mechanism types per slot" do
      requirements = described_class.slot_requirements

      expect(requirements[:barrel][:allowed_types]).to include(
        "PlayerMechanisms::Barrel85mm"
      )
    end
  end

  describe ".mechanism_allowed_in_slot?" do
    let(:barrel_85mm) { build(:barrel_85mm) }
    let(:barrel_155mm) { build_stubbed(:barrel_155mm) } # Future mechanism

    it "allows compatible mechanisms" do
      expect(described_class.mechanism_allowed_in_slot?(:barrel, barrel_85mm)).to be true
    end

    it "rejects incompatible mechanisms" do
      expect(described_class.mechanism_allowed_in_slot?(:barrel, barrel_155mm)).to be false
    end
  end

  describe ".validate_loadout" do
    let(:player) { create(:player) }

    context "with valid loadout" do
      let(:loadout) do
        create(:player_loadout, player:, platform_type: "qf_18_pounder")
      end

      before do
        create(:elevation_dial, player:, slot_key: "elevation")
        create(:deflection_screw, player:, slot_key: "deflection")
        create(:cartridge_85mm, player:, slot_key: "cartridge")
        create(:barrel_85mm, player:, slot_key: "barrel")
        create(:breech_qf, player:, slot_key: "breech")
        create(:recoil_system, player:, slot_key: "recoil_system")
        create(:optical_sight, player:, slot_key: "sight")

        # Attach all mechanisms to loadout via slots
        player.player_mechanisms.each do |mech|
          create(:player_loadout_slot,
            player_loadout: loadout,
            player_mechanism: mech,
            slot_key: mech.slot_key
          )
        end
        loadout.reload
      end

      it "returns no errors" do
        errors = described_class.validate_loadout(loadout)
        expect(errors).to be_empty
      end
    end

    context "with missing required slot" do
      let(:loadout) do
        create(:player_loadout, player:, platform_type: "qf_18_pounder")
      end

      it "returns error for missing slot" do
        errors = described_class.validate_loadout(loadout)
        expect(errors).to include(/Required slot 'elevation' is not filled/)
      end
    end

    context "with wrong mechanism type in slot" do
      let(:loadout) do
        create(:player_loadout, player:, platform_type: "qf_18_pounder")
      end

      before do
        # Try to put 155mm barrel in 85mm slot
        wrong_barrel = create(:barrel_155mm, player:, slot_key: "barrel")
        create(:player_loadout_slot,
          player_loadout: loadout,
          player_mechanism: wrong_barrel,
          slot_key: "barrel"
        )
        loadout.reload
      end

      it "returns error for incompatible mechanism" do
        errors = described_class.validate_loadout(loadout)
        expect(errors).to include(/Barrel155mm is not allowed in slot 'barrel'/)
      end
    end
  end

  describe ".validate_additional_constraints" do
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player:, platform_type: "qf_18_pounder") }

    context "with barrel length out of range" do
      before do
        barrel = create(:barrel_85mm, player:,
          slot_key: "barrel",
          modifiers: { length_meters: 3.5 } # Too long!
        )
        create(:player_loadout_slot,
          player_loadout: loadout,
          player_mechanism: barrel,
          slot_key: "barrel"
        )
        loadout.reload
      end

      it "returns error for invalid barrel length" do
        errors = described_class.validate_additional_constraints(loadout)
        expect(errors).to include(/barrel length must be between 2.0m and 2.8m/)
      end
    end
  end
end
```

### Integration Tests: Loadout Validation

```ruby
# test/models/player_loadout_platform_validation_spec.rb
RSpec.describe PlayerLoadout, type: :model do
  let(:player) { create(:player) }

  describe "platform validation" do
    context "with qf_18_pounder platform" do
      let(:loadout) { build(:player_loadout, player:, platform_type: "qf_18_pounder") }

      it "is invalid without required mechanisms" do
        expect(loadout).not_to be_valid
        expect(loadout.errors[:base]).to include(/Required slot .* is not filled/)
      end

      it "is valid with all required mechanisms" do
        # Create all required mechanisms and attach to loadout
        # (Full setup as in unit test above)

        expect(loadout).to be_valid
      end
    end

    context "with unknown platform type" do
      let(:loadout) { build(:player_loadout, player:, platform_type: "nonexistent_platform") }

      it "raises UnknownPlatformError" do
        expect { loadout.valid? }.to raise_error(Artillery::Platforms::UnknownPlatformError)
      end
    end
  end

  describe "#missing_required_slots" do
    let(:loadout) { create(:player_loadout, player:, platform_type: "qf_18_pounder") }

    context "with no mechanisms" do
      it "returns all required slots" do
        missing = loadout.missing_required_slots
        expect(missing).to include("elevation", "barrel", "cartridge")
      end
    end

    context "with some mechanisms" do
      before do
        elevation = create(:elevation_dial, player:, slot_key: "elevation")
        create(:player_loadout_slot,
          player_loadout: loadout,
          player_mechanism: elevation,
          slot_key: "elevation"
        )
        loadout.reload
      end

      it "returns only unfilled required slots" do
        missing = loadout.missing_required_slots
        expect(missing).not_to include("elevation")
        expect(missing).to include("barrel")
      end
    end
  end
end
```

---

## Migration Strategy

### Database Changes Required

**None for Phase 1!** The `platform_type` column already exists in `player_loadouts` table.

### Code Deployment Steps

1. Deploy platform registry and base class
2. Deploy QF 18-pounder platform definition
3. Update PlayerLoadout validations (in same deploy)
4. Run tests to verify existing loadouts
5. Fix any invalid loadouts via rake task (if needed)

### Handling Existing Data

```ruby
# lib/tasks/platform_migration.rake
namespace :platform do
  desc "Validate existing loadouts against platform requirements"
  task validate_all: :environment do
    PlayerLoadout.find_each do |loadout|
      next unless loadout.platform_type.present?

      begin
        platform = Artillery::Platforms::Registry.get(loadout.platform_type)
        errors = platform.validate_loadout(loadout)

        if errors.any?
          puts "Loadout #{loadout.id} (#{loadout.label}) has errors:"
          errors.each { |e| puts "  - #{e}" }
        end
      rescue Artillery::Platforms::UnknownPlatformError
        puts "Loadout #{loadout.id} has unknown platform: #{loadout.platform_type}"
      end
    end
  end

  desc "Set default platform_type for loadouts without one"
  task :set_defaults => :environment do
    PlayerLoadout.where(platform_type: [nil, ""]).find_each do |loadout|
      # Heuristic: check what mechanisms they have to guess platform
      if loadout.player_mechanisms.any? { |m| m.is_a?(PlayerMechanisms::Barrel85mm) }
        loadout.update!(platform_type: "qf_18_pounder")
        puts "Set loadout #{loadout.id} to qf_18_pounder"
      end
    end
  end
end
```

---

## Future Enhancements

### 1. Platform Variants

Allow platform subclasses for minor variations:

```ruby
class Qf18PounderMk2 < Qf18Pounder
  def self.key
    "qf_18_pounder_mk2"
  end

  def self.name
    "QF 18-pounder Mk II (Improved)"
  end

  # Override specific slots to allow upgraded mechanisms
  def self.slot_requirements
    super.merge(
      barrel: {
        required: true,
        allowed_types: [
          "PlayerMechanisms::Barrel85mm",
          "PlayerMechanisms::Barrel85mmMk2" # Upgraded variant
        ]
      }
    )
  end
end
```

### 2. Platform Unlocking

Track which platforms players have unlocked:

```ruby
create_table :player_platform_unlocks do |t|
  t.references :player
  t.string :platform_key
  t.datetime :unlocked_at
  t.timestamps
end
```

### 3. Platform-Specific Achievements

Achievements tied to platform mastery:

```ruby
# "QF 18-pounder Ace" - 100 kills with QF 18-pounder
# "Long Range Specialist" - Hit target > 5km with any platform
```

### 4. Platform Balancing Modifiers

Global balance adjustments without changing mechanism stats:

```ruby
class Qf18Pounder < Base
  def self.global_modifiers
    {
      velocity_multiplier: 1.0,
      accuracy_bonus: 0.02,
      reload_speed_multiplier: 1.1
    }
  end
end
```

### 5. Platform-Specific UI

Custom UI elements per platform:

```ruby
class Qf18Pounder < Base
  def self.ui_components
    {
      aiming_interface: "dial_and_screw",
      charge_selector: "sliding_scale",
      sight_display: "range_estimator"
    }
  end
end
```

---

## Design Rationale

### Why Code-Based Platforms?

**Decision:** Platforms as Ruby classes, NOT database records

**Pros:**
- ✅ Version controlled (Git history of balance changes)
- ✅ Complex validation logic in Ruby, not SQL
- ✅ No migrations for balance updates
- ✅ Easier to test (unit tests, not integration tests)
- ✅ Compile-time safety (Ruby will error if method missing)
- ✅ Fast (no DB queries to fetch platform rules)

**Cons:**
- ❌ Can't add platforms without code deploy
- ❌ Non-programmers can't create platforms (need Ruby knowledge)
- ❌ No admin UI to edit platforms

**Mitigation for Cons:**
- Platforms are game design artifacts, should require developer involvement
- Could add YAML-based platform definitions later if needed (parse into Ruby objects)
- Admin UI not needed (platforms don't change frequently)

### Why Constraint Validation?

**Decision:** Platforms validate loadouts, don't construct them

**Rationale:**
- Players build loadouts incrementally (add mechanisms one at a time)
- Validation provides feedback: "You need a barrel to use this platform"
- Allows flexibility: swap mechanisms, try different combos within rules
- Clear error messages: "Wrong caliber barrel" vs silent failure

### Why Slot-Based System?

**Decision:** Mechanisms fill named slots (elevation, barrel, etc.)

**Benefits:**
- Clear UI: "Fill the barrel slot with an 85mm barrel"
- Extensible: Add new slots without breaking old platforms
- Swappable: Upgrade barrel without affecting other mechanisms
- Testable: Check "is barrel slot filled?" independently

---

## Summary

### What We're Building

1. **Platform Registry**: Central lookup for all platform definitions
2. **Platform Base Class**: Common validation and structure for all platforms
3. **QF 18-Pounder Platform**: First concrete platform with slot requirements
4. **PlayerLoadout Integration**: Validation hooks ensure loadouts match platform rules
5. **Tests**: Comprehensive coverage of platform validation logic

### What Players Experience

- **Choose Platform**: "I want to use a QF 18-pounder"
- **Build Loadout**: Add compatible mechanisms to each required slot
- **Get Feedback**: "You need an 85mm barrel" or "This barrel is too long for QF 18-pounder"
- **Customize**: Choose between different 85mm barrels (standard, chrome-lined, etc.)
- **Upgrade**: Better mechanisms unlock over time, but stay compatible with platform

### What Game Designers Control

- Which mechanisms are compatible with which platforms
- Platform-specific constraints (barrel length, caliber matching, etc.)
- Balance across platforms (via mechanism stats and platform characteristics)
- Addition of new platforms without touching existing mechanism code

### Next Steps

1. Implement Platform Registry and Base class
2. Implement QF 18-pounder platform definition
3. Add validation to PlayerLoadout model
4. Write comprehensive tests
5. Validate existing player loadouts (if any)
6. Document platform creation process for future platforms

---

**End of Plan**
