# Mechanism System Design Plans

**Date:** 2025-11-15
**Status:** Design Phase - Three Competing Approaches

---

## Problem Statement

We need a mechanism system that:

1. **Supports Multiple Artillery Platforms** - Starting with QF 18-pounder (Edwardian breechloader)
2. **Handles Diverse Mechanism Types** with varying concerns:
   - **Ballistic-affecting**: Barrel, cartridge, elevation dial, deflection control → feed into physics engine
   - **Turn-order affecting**: Recoil system, breech, loading mechanics → determine who shoots next
   - **UI/Information**: Sights → provide player with better aiming data/feedback
   - **Non-gameplay**: Carriage, towage → may affect weight, cost, logistics but not direct simulation
3. **Accommodates Variants** - Multiple barrels with same caliber (85mm) but different lengths/construction
4. **Tracks Attributes**: Cost (currency), weight (kg), upgrade levels, modifiers
5. **Integrates Flexibly**:
   - Some mechanisms contribute to `Ballistic3D` inputs
   - Some create hooks/affectors for the physics engine
   - Some provide UI metadata (sight accuracy, range estimates)
   - Some affect turn order/timing mechanics outside the engine
6. **Uses STI** for type specialization where beneficial
7. **Allows Per-Match Randomization** while maintaining determinism

---

## Design Constraints

### Existing Architecture

**Current Flow (from concept.md):**
```
PlayerMechanism (DB, STI)
  ↓
ResolvedMechanismRuntime (instantiated per match with randomization)
  ↓
MechanismResolver (aggregates simulations)
  ↓
Ballistic3D::Inputs (angle_deg, initial_velocity, shell_weight, deflection_deg, area_of_effect)
  ↓
Ballistic3D Engine (physics simulation)
```

**Key Inputs to Ballistic3D:**
- `angle_deg` - Elevation angle
- `initial_velocity` - Muzzle velocity (m/s)
- `shell_weight` - Projectile mass (kg)
- `deflection_deg` - Horizontal aim offset
- `area_of_effect` - Blast radius (currently unused in ballistic calc)
- `surface_area` - Cross-sectional area for drag calculations (hardcoded to 0.05 m² currently)

**Engine Configuration:**
- `affectors: []` - Array of force applicators (gravity, drag, wind)
- `before_tick_hooks: []` - Pre-integration behaviors (parachute deployment, etc.)
- `after_tick_hooks: []` - Post-integration behaviors

### QF 18-Pounder Mechanisms (Initial Platform)

| Mechanism | Purpose | Ballistic Impact | Other Impact |
|-----------|---------|------------------|--------------|
| **Barrel** | Projectile acceleration | Length → initial_velocity, surface_area; Construction → accuracy variance | Weight affects carriage mobility |
| **Breech** | Loading system | None direct | Loading time → turn order |
| **Cartridge** | Combined shell+charge | Shell weight, charge amount → initial_velocity | Cost per shot |
| **Deflection Control** | Horizontal aim | Player input → deflection_deg | UI: control precision, max range |
| **Elevation Dial** | Vertical aim | Player input → angle_deg | UI: precision, graduations |
| **Recoil System** | Absorbs firing forces | Slight accuracy penalty if poor | Recoil time → turn order |
| **Carriage** | Mounting platform | None direct | Weight, stability → setup time |
| **Sight** | Aiming assistance | None direct | UI: provides distance estimates, windage corrections |
| **Towage** | Mobility system | None direct | Weight limit, movement speed between positions |

### Key Challenges

1. **Heterogeneous Outputs**: Not all mechanisms contribute to the same concerns (ballistic vs. turn-order vs. UI metadata)
2. **Chaining Dependencies**: Barrel length affects velocity; cartridge charge affects velocity; both combine
3. **Upgrade Paths**: Each mechanism needs distinct upgrade modifiers (e.g., barrel: +velocity, +accuracy; sight: +distance_estimate_accuracy)
4. **UI Rendering**: Controllers need to know how to display mechanism controls (slider? dial? dropdown?)
5. **Runtime Resolution**: Per-match randomization must be deterministic and frozen
6. **Engine Flexibility**: System must support non-ballistic engines in future (e.g., laser targeting, chemical mortars)

---

## Design Plan A: Multi-Concern Component Architecture

### Philosophy

Mechanisms are **multi-faceted components** that explicitly declare which concerns they affect via **concern modules/interfaces**. Each mechanism can implement multiple concerns (ballistic, turn-order, UI, etc.), and a resolver orchestrates their contributions.

### Core Structure

#### 1. Mechanism Base Class (STI Root)

```ruby
# app/models/player_mechanism.rb
class PlayerMechanism < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots
  has_many :player_loadouts, through: :player_loadout_slots

  # STI column
  self.inheritance_column = 'type'

  # Common attributes
  # - type (STI discriminator)
  # - slot_key (e.g., :barrel, :elevation_dial)
  # - upgrade_level (0-5)
  # - modifiers (JSONB: { precision_bonus: 0.2, velocity_multiplier: 1.1 })
  # - base_cost (currency)
  # - base_weight (kg)

  # Generate runtime instance for a match
  def to_runtime(match:, random_seed:)
    runtime_class.new(
      mechanism: self,
      match: match,
      random_seed: random_seed
    )
  end

  # Override in subclasses
  def runtime_class
    raise NotImplementedError
  end

  # Declare which concerns this mechanism addresses
  def concerns
    []
  end
end
```

#### 2. Concern Modules

Each concern defines a protocol for mechanisms to implement:

```ruby
# lib/artillery/mechanisms/concerns/ballistic_contributor.rb
module Artillery
  module Mechanisms
    module Concerns
      module BallisticContributor
        extend ActiveSupport::Concern

        # Must be implemented by mechanism runtime
        # @param player_input [Hash] Raw player input { elevation: 4, powder: 2, ... }
        # @return [Hash] Ballistic contributions { angle_deg: 35.2, initial_velocity: 580, ... }
        def contribute_to_ballistic(player_input)
          raise NotImplementedError
        end
      end
    end
  end
end

# lib/artillery/mechanisms/concerns/turn_order_contributor.rb
module Artillery
  module Mechanisms
    module Concerns
      module TurnOrderContributor
        extend ActiveSupport::Concern

        # @return [Float] Time penalty/bonus in seconds for next turn
        def turn_order_delay
          raise NotImplementedError
        end
      end
    end
  end
end

# lib/artillery/mechanisms/concerns/ui_metadata_provider.rb
module Artillery
  module Mechanisms
    module Concerns
      module UIMetadataProvider
        extend ActiveSupport::Concern

        # @return [Hash] Metadata for UI rendering
        # Example: { control_type: :slider, min: 0, max: 90, step: 1, unit: "degrees" }
        def ui_metadata
          raise NotImplementedError
        end

        # @return [Hash] Player assistance data (e.g., estimated impact point, wind correction)
        def assistance_data(current_input)
          {}
        end
      end
    end
  end
end

# lib/artillery/mechanisms/concerns/engine_configurator.rb
module Artillery
  module Mechanisms
    module Concerns
      module EngineConfigurator
        extend ActiveSupport::Concern

        # @return [Array<Affector>] Affectors to add to engine
        def affectors
          []
        end

        # @return [Array<Hook>] Hooks to add to engine
        def hooks
          []
        end
      end
    end
  end
end
```

#### 3. Concrete Mechanism Example: Barrel

```ruby
# app/models/player_mechanisms/barrel.rb
class PlayerMechanisms::Barrel < PlayerMechanism
  # Concerns this mechanism addresses
  def concerns
    [:ballistic_contributor, :engine_configurator]
  end

  def runtime_class
    PlayerMechanisms::BarrelRuntime
  end

  # Variants stored in modifiers JSONB:
  # {
  #   variant: "standard" | "heavy" | "lightweight",
  #   length_meters: 2.5,
  #   construction: "steel" | "chrome_lined",
  #   wear_factor: 0.95  # randomized per match
  # }

  def base_velocity_multiplier
    case modifiers['variant']
    when 'heavy' then 1.15
    when 'lightweight' then 0.95
    else 1.0
    end
  end

  def accuracy_variance_degrees
    base = case modifiers['construction']
    when 'chrome_lined' then 0.5
    else 1.0
    end

    # Upgrades reduce variance
    base * (1.0 - upgrade_level * 0.1)
  end
end

# app/models/player_mechanisms/barrel_runtime.rb
class PlayerMechanisms::BarrelRuntime
  include Artillery::Mechanisms::Concerns::BallisticContributor
  include Artillery::Mechanisms::Concerns::EngineConfigurator

  attr_reader :mechanism, :match, :velocity_multiplier, :accuracy_offset

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism
    @match = match

    # Deterministic randomization using match seed
    rng = Random.new(random_seed + mechanism.id)

    # Apply wear factor randomization (±5%)
    wear = mechanism.modifiers['wear_factor'] || 1.0
    @velocity_multiplier = mechanism.base_velocity_multiplier * wear * (0.95 + rng.rand * 0.1)

    # Randomize accuracy offset within variance
    variance = mechanism.accuracy_variance_degrees
    @accuracy_offset = (rng.rand - 0.5) * variance * 2
  end

  def contribute_to_ballistic(player_input)
    # Barrels modify initial velocity and angle accuracy
    {
      initial_velocity_multiplier: @velocity_multiplier,
      angle_deg_offset: @accuracy_offset
    }
  end

  def affectors
    # Could add barrel-specific affectors (e.g., rifling spin effect)
    []
  end

  def hooks
    []
  end
end
```

#### 4. Concrete Mechanism Example: Elevation Dial

```ruby
# app/models/player_mechanisms/elevation_dial.rb
class PlayerMechanisms::ElevationDial < PlayerMechanism
  def concerns
    [:ballistic_contributor, :ui_metadata_provider]
  end

  def runtime_class
    PlayerMechanisms::ElevationDialRuntime
  end

  # Modifiers:
  # {
  #   graduations: "coarse" | "fine" | "vernier",
  #   degrees_per_click: 2.0,
  #   max_elevation: 90
  # }

  def degrees_per_click
    base = case modifiers['graduations']
    when 'fine' then 0.5
    when 'vernier' then 0.1
    else 2.0
    end

    # Upgrades improve precision
    base * (1.0 - upgrade_level * 0.05)
  end
end

class PlayerMechanisms::ElevationDialRuntime
  include Artillery::Mechanisms::Concerns::BallisticContributor
  include Artillery::Mechanisms::Concerns::UIMetadataProvider

  attr_reader :mechanism, :degrees_per_click_runtime

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism

    rng = Random.new(random_seed + mechanism.id)

    # Randomize dial calibration slightly
    @degrees_per_click_runtime = mechanism.degrees_per_click * (0.98 + rng.rand * 0.04)
  end

  def contribute_to_ballistic(player_input)
    # Convert player's click input to degrees
    clicks = player_input[:elevation] || 0
    angle = clicks * @degrees_per_click_runtime

    { angle_deg: angle }
  end

  def ui_metadata
    {
      control_type: :dial,
      input_key: :elevation,
      label: "Elevation",
      min: 0,
      max: (mechanism.modifiers['max_elevation'] / @degrees_per_click_runtime).to_i,
      step: 1,
      unit: "clicks",
      conversion: "#{@degrees_per_click_runtime.round(2)}° per click"
    }
  end

  def assistance_data(current_input)
    clicks = current_input[:elevation] || 0
    estimated_angle = clicks * @degrees_per_click_runtime

    {
      estimated_angle_degrees: estimated_angle.round(1),
      estimated_range_meters: estimate_range(estimated_angle)
    }
  end

  private

  def estimate_range(angle_deg)
    # Simplified range formula (assuming no air resistance)
    # R = v² * sin(2θ) / g
    # Need to access cartridge velocity - this is a design challenge!
    # For now, assume average velocity
    v = 500 # m/s, placeholder
    g = 9.81
    angle_rad = angle_deg * Math::PI / 180
    (v**2 * Math.sin(2 * angle_rad) / g).round(0)
  end
end
```

#### 5. Concrete Mechanism Example: Recoil System

```ruby
# app/models/player_mechanisms/recoil_system.rb
class PlayerMechanisms::RecoilSystem < PlayerMechanism
  def concerns
    [:turn_order_contributor, :ballistic_contributor]
  end

  def runtime_class
    PlayerMechanisms::RecoilSystemRuntime
  end

  # Modifiers:
  # {
  #   type: "basic_spring" | "hydropneumatic" | "soft_recoil",
  #   recovery_time_base: 3.0  # seconds
  # }
end

class PlayerMechanisms::RecoilSystemRuntime
  include Artillery::Mechanisms::Concerns::TurnOrderContributor
  include Artillery::Mechanisms::Concerns::BallisticContributor

  attr_reader :mechanism, :recovery_time

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism

    rng = Random.new(random_seed + mechanism.id)

    base_time = mechanism.modifiers['recovery_time_base'] || 3.0
    upgrade_reduction = mechanism.upgrade_level * 0.2

    @recovery_time = base_time * (1.0 - upgrade_reduction) * (0.95 + rng.rand * 0.1)
  end

  def turn_order_delay
    @recovery_time
  end

  def contribute_to_ballistic(player_input)
    # Poor recoil systems add slight accuracy penalty
    penalty = case mechanism.modifiers['type']
    when 'basic_spring' then 0.5
    when 'hydropneumatic' then 0.1
    else 0.3
    end

    {
      angle_deg_offset: (rand - 0.5) * penalty,
      deflection_deg_offset: (rand - 0.5) * penalty
    }
  end
end
```

#### 6. Concrete Mechanism Example: Sight

```ruby
# app/models/player_mechanisms/sight.rb
class PlayerMechanisms::Sight < PlayerMechanism
  def concerns
    [:ui_metadata_provider]
  end

  def runtime_class
    PlayerMechanisms::SightRuntime
  end

  # Modifiers:
  # {
  #   type: "iron_sights" | "telescopic" | "rangefinder",
  #   accuracy_bonus: 0.8  # how accurate distance estimates are (0-1)
  # }
end

class PlayerMechanisms::SightRunt
  include Artillery::Mechanisms::Concerns::UIMetadataProvider

  attr_reader :mechanism, :estimate_accuracy

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism

    rng = Random.new(random_seed + mechanism.id)

    base_accuracy = mechanism.modifiers['accuracy_bonus'] || 0.5
    upgrade_bonus = mechanism.upgrade_level * 0.1

    @estimate_accuracy = [base_accuracy + upgrade_bonus, 1.0].min
  end

  def ui_metadata
    {
      control_type: :info_display,
      label: "Sight",
      type: mechanism.modifiers['type']
    }
  end

  def assistance_data(current_input)
    # Provide distance estimate to target (with error based on accuracy)
    # This would integrate with target position data from match
    true_distance = 500 # placeholder, would come from match.target.distance_from_origin

    error_margin = true_distance * (1.0 - @estimate_accuracy) * 0.2
    estimated_distance = true_distance + (rand - 0.5) * error_margin * 2

    {
      estimated_target_distance: estimated_distance.round(0),
      accuracy_rating: (@estimate_accuracy * 100).round(0),
      windage_correction: calculate_windage_hint
    }
  end

  private

  def calculate_windage_hint
    # Could integrate with match wind conditions
    "Wind: Light from West (2 clicks right recommended)"
  end
end
```

#### 7. Resolution Orchestrator

```ruby
# lib/artillery/mechanisms/resolver.rb
module Artillery
  module Mechanisms
    class Resolver
      attr_reader :runtimes, :player_input

      def initialize(runtimes, player_input)
        @runtimes = runtimes
        @player_input = player_input
      end

      # Aggregate all ballistic contributions
      def ballistic_attributes
        ballistic_runtimes = @runtimes.select { |r| r.is_a?(Concerns::BallisticContributor) }

        contributions = ballistic_runtimes.map { |runtime| runtime.contribute_to_ballistic(@player_input) }

        # Merge contributions with intelligent aggregation
        merged = {}
        contributions.each do |contrib|
          contrib.each do |key, value|
            if key.to_s.end_with?('_multiplier')
              merged[key] = (merged[key] || 1.0) * value
            elsif key.to_s.end_with?('_offset')
              merged[key] = (merged[key] || 0.0) + value
            else
              # Direct values (last wins, or could implement priority system)
              merged[key] = value
            end
          end
        end

        # Convert to engine input format
        resolve_final_values(merged)
      end

      # Collect all affectors/hooks for engine configuration
      def engine_affectors
        @runtimes
          .select { |r| r.is_a?(Concerns::EngineConfigurator) }
          .flat_map(&:affectors)
      end

      def engine_hooks
        @runtimes
          .select { |r| r.is_a?(Concerns::EngineConfigurator) }
          .flat_map(&:hooks)
      end

      # Calculate total turn order delay
      def turn_order_delay
        @runtimes
          .select { |r| r.is_a?(Concerns::TurnOrderContributor) }
          .sum(&:turn_order_delay)
      end

      # Collect all UI metadata
      def ui_metadata
        @runtimes
          .select { |r| r.is_a?(Concerns::UIMetadataProvider) }
          .map { |r| { slot_key: r.mechanism.slot_key, metadata: r.ui_metadata } }
      end

      # Collect all assistance data
      def assistance_data
        @runtimes
          .select { |r| r.is_a?(Concerns::UIMetadataProvider) }
          .map { |r| r.assistance_data(@player_input) }
          .reduce({}, :merge)
      end

      private

      def resolve_final_values(merged)
        # Apply multipliers to base values
        base_velocity = merged[:initial_velocity] || 500
        base_angle = (merged[:angle_deg] || 45) + (merged[:angle_deg_offset] || 0)
        base_deflection = (merged[:deflection_deg] || 0) + (merged[:deflection_deg_offset] || 0)

        {
          angle_deg: base_angle * (merged[:angle_deg_multiplier] || 1.0),
          initial_velocity: base_velocity * (merged[:initial_velocity_multiplier] || 1.0),
          shell_weight: merged[:shell_weight] || 25,
          deflection_deg: base_deflection,
          area_of_effect: merged[:area_of_effect] || 0,
          surface_area: merged[:surface_area] || 0.05
        }
      end
    end
  end
end
```

### Database Schema

```ruby
create_table :player_mechanisms do |t|
  t.references :player, null: false, foreign_key: true
  t.string :type, null: false              # STI: PlayerMechanisms::Barrel, etc.
  t.string :slot_key, null: false          # :barrel, :elevation_dial, etc.
  t.integer :upgrade_level, default: 0
  t.jsonb :modifiers, default: {}          # Variant-specific data
  t.decimal :base_cost, precision: 10, scale: 2
  t.decimal :base_weight, precision: 8, scale: 2  # kg
  t.timestamps
end

create_table :player_loadouts do |t|
  t.references :player, null: false, foreign_key: true
  t.string :label, null: false
  t.string :engine_type, default: 'ballistic_3d'
  t.string :platform_type, null: false     # 'qf_18_pounder', future: 'mortar', 'howitzer'
  t.boolean :default, default: false
  t.timestamps
end

create_table :player_loadout_slots do |t|
  t.references :player_loadout, null: false, foreign_key: true
  t.references :player_mechanism, null: false, foreign_key: true
  t.string :slot_key, null: false          # Must match mechanism.slot_key
  t.timestamps

  t.index [:player_loadout_id, :slot_key], unique: true
end

create_table :resolved_mechanism_runtimes do |t|
  t.references :match, null: false, foreign_key: true
  t.references :player, null: false, foreign_key: true
  t.references :player_mechanism, null: false, foreign_key: true
  t.string :runtime_type, null: false      # Runtime class name
  t.jsonb :randomized_state, null: false   # Serialized runtime state
  t.integer :random_seed, null: false
  t.timestamps
end
```

### Pros

✅ **Explicit Separation of Concerns** - Clear modules for ballistic, turn-order, UI, engine config
✅ **Composable** - Mechanisms implement only the concerns they need
✅ **Extensible** - New concerns added without modifying existing mechanisms
✅ **Type-Safe** - Runtime type checking via module inclusion
✅ **Flexible Resolution** - Resolver handles intelligent merging (multiply vs. add vs. override)
✅ **Testable** - Each concern can be tested in isolation

### Cons

❌ **Verbose** - Lots of boilerplate for concern modules and runtime classes
❌ **Complex Resolution Logic** - Merging multipliers, offsets, direct values requires careful design
❌ **Cross-Mechanism Dependencies** - Sight needs cartridge velocity for range estimates (tight coupling)
❌ **Serialization Overhead** - Runtime state must be serialized to `resolved_mechanism_runtimes` table
❌ **Learning Curve** - Developers must understand concern system and resolution rules

### Usage Example

```ruby
# Match setup
player = Player.find(1)
loadout = player.player_loadouts.find_by(label: "My QF 18-Pounder")
match = Match.create!(players: [player], random_seed: 12345)

# Instantiate runtimes
runtimes = loadout.player_mechanisms.map do |mech|
  mech.to_runtime(match: match, random_seed: match.random_seed)
end

# Turn submission
player_input = { elevation: 15, powder: 3, deflection: 2 }
resolver = Artillery::Mechanisms::Resolver.new(runtimes, player_input)

# Get engine configuration
engine = Artillery::Engines::Ballistic3D.new(
  affectors: [
    Artillery::Engines::Affectors::Gravity.new,
    Artillery::Engines::Affectors::AirResistance.new,
    *resolver.engine_affectors
  ],
  before_tick_hooks: resolver.engine_hooks
)

# Simulate
ballistic_attrs = resolver.ballistic_attributes
result = engine.simulate(Artillery::Engines::Inputs::Ballistic3D.new(**ballistic_attrs))

# Calculate turn order
next_turn_time = Time.current + resolver.turn_order_delay

# Provide UI feedback
ui_data = resolver.ui_metadata
assistance = resolver.assistance_data
```

---

## Design Plan B: Pipeline/Resolver Architecture

### Philosophy

Mechanisms are **pipeline stages** that transform data as it flows from player input → engine input. Each mechanism declares its **input dependencies** and **output contributions**, and a resolver builds a dependency graph to execute them in correct order. This eliminates ad-hoc merging logic.

### Core Structure

#### 1. Mechanism Base Class

```ruby
# app/models/player_mechanism.rb
class PlayerMechanism < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots
  has_many :player_loadouts, through: :player_loadout_slots

  self.inheritance_column = 'type'

  # Common attributes: type, slot_key, upgrade_level, modifiers, base_cost, base_weight

  def to_runtime(match:, random_seed:)
    runtime_class.new(
      mechanism: self,
      match: match,
      random_seed: random_seed
    )
  end

  def runtime_class
    raise NotImplementedError
  end

  # NEW: Declare input/output keys for pipeline
  def input_keys
    []
  end

  def output_keys
    []
  end

  # NEW: Execution priority (lower = earlier in pipeline)
  def priority
    50
  end
end
```

#### 2. Mechanism Runtime Base

```ruby
# lib/artillery/mechanisms/runtime_base.rb
module Artillery
  module Mechanisms
    class RuntimeBase
      attr_reader :mechanism, :match

      def initialize(mechanism:, match:, random_seed:)
        @mechanism = mechanism
        @match = match
        @random_seed = random_seed
        initialize_runtime
      end

      # Override to set up randomized state
      def initialize_runtime
      end

      # Main pipeline method: receives context hash, returns contributions
      # @param context [Hash] Accumulated values from previous pipeline stages
      # @return [Hash] New/modified values to merge into context
      def resolve(context)
        raise NotImplementedError
      end

      # Optional: validate that required inputs are present
      def validate_inputs!(context)
        mechanism.input_keys.each do |key|
          unless context.key?(key)
            raise ArgumentError, "Missing required input: #{key} for #{mechanism.class.name}"
          end
        end
      end

      # Optional: provide metadata for UI/assistance
      def metadata
        {}
      end

      # Optional: provide turn-order effects
      def turn_order_delay
        0.0
      end
    end
  end
end
```

#### 3. Concrete Example: Cartridge (Source)

```ruby
# app/models/player_mechanisms/cartridge.rb
class PlayerMechanisms::Cartridge < PlayerMechanism
  def runtime_class
    PlayerMechanisms::CartridgeRuntime
  end

  def input_keys
    [:powder_charges]  # Player input
  end

  def output_keys
    [:base_initial_velocity, :shell_weight, :surface_area]
  end

  def priority
    10  # Execute early (provides base values)
  end

  # Modifiers:
  # {
  #   shell_weight_kg: 8.4,
  #   charge_velocity_per_unit: 50,  # m/s per powder charge
  #   base_velocity: 400,
  #   caliber_mm: 84.5,
  #   construction: "steel" | "composite"
  # }
end

class PlayerMechanisms::CartridgeRuntime < Artillery::Mechanisms::RuntimeBase
  attr_reader :velocity_variance, :weight_variance

  def initialize_runtime
    rng = Random.new(@random_seed + mechanism.id)

    # Randomize manufacturing variance
    @velocity_variance = 0.95 + rng.rand * 0.1  # ±5%
    @weight_variance = 0.98 + rng.rand * 0.04   # ±2%
  end

  def resolve(context)
    validate_inputs!(context)

    powder_charges = context[:powder_charges] || 1

    base_v = mechanism.modifiers['base_velocity'] || 400
    charge_increment = mechanism.modifiers['charge_velocity_per_unit'] || 50

    velocity = (base_v + powder_charges * charge_increment) * @velocity_variance

    weight = (mechanism.modifiers['shell_weight_kg'] || 8.4) * @weight_variance

    # Calculate surface area from caliber (assuming spherical)
    caliber_m = (mechanism.modifiers['caliber_mm'] || 84.5) / 1000.0
    area = Math::PI * (caliber_m / 2) ** 2

    {
      base_initial_velocity: velocity,
      shell_weight: weight,
      surface_area: area,
      caliber_mm: mechanism.modifiers['caliber_mm']
    }
  end

  def metadata
    {
      slot: :cartridge,
      control_type: :slider,
      input_key: :powder_charges,
      label: "Powder Charges",
      min: 1,
      max: 5,
      step: 1,
      unit: "charges"
    }
  end
end
```

#### 4. Concrete Example: Barrel (Transformer)

```ruby
# app/models/player_mechanisms/barrel.rb
class PlayerMechanisms::Barrel < PlayerMechanism
  def runtime_class
    PlayerMechanisms::BarrelRuntime
  end

  def input_keys
    [:base_initial_velocity]  # From cartridge
  end

  def output_keys
    [:initial_velocity]  # Modified velocity
  end

  def priority
    20  # Execute after cartridge
  end

  # Modifiers:
  # {
  #   length_meters: 2.5,
  #   construction: "standard" | "chrome_lined",
  #   velocity_multiplier: 1.1
  # }
end

class PlayerMechanisms::BarrelRuntime < Artillery::Mechanisms::RuntimeBase
  attr_reader :velocity_multiplier, :wear_factor

  def initialize_runtime
    rng = Random.new(@random_seed + mechanism.id)

    base_multiplier = mechanism.modifiers['velocity_multiplier'] || 1.0
    upgrade_bonus = 1.0 + mechanism.upgrade_level * 0.02

    @wear_factor = 0.95 + rng.rand * 0.1
    @velocity_multiplier = base_multiplier * upgrade_bonus * @wear_factor
  end

  def resolve(context)
    validate_inputs!(context)

    base_velocity = context[:base_initial_velocity]

    {
      initial_velocity: base_velocity * @velocity_multiplier
    }
  end

  def metadata
    {
      slot: :barrel,
      display_type: :info,
      label: "Barrel",
      details: {
        length: "#{mechanism.modifiers['length_meters']}m",
        construction: mechanism.modifiers['construction'],
        velocity_bonus: "#{((@velocity_multiplier - 1.0) * 100).round(1)}%"
      }
    }
  end
end
```

#### 5. Concrete Example: Elevation Dial (Input Transformer)

```ruby
# app/models/player_mechanisms/elevation_dial.rb
class PlayerMechanisms::ElevationDial < PlayerMechanism
  def runtime_class
    PlayerMechanisms::ElevationDialRuntime
  end

  def input_keys
    [:elevation_clicks]  # Player input
  end

  def output_keys
    [:angle_deg]
  end

  def priority
    15  # Execute early (converts player input)
  end

  # Modifiers: { degrees_per_click: 2.0, max_elevation: 90 }
end

class PlayerMechanisms::ElevationDialRuntime < Artillery::Mechanisms::RuntimeBase
  attr_reader :degrees_per_click, :accuracy_variance

  def initialize_runtime
    rng = Random.new(@random_seed + mechanism.id)

    base_dpc = mechanism.modifiers['degrees_per_click'] || 2.0
    upgrade_precision = 1.0 - mechanism.upgrade_level * 0.05

    @degrees_per_click = base_dpc * upgrade_precision
    @accuracy_variance = (rng.rand - 0.5) * (2.0 - mechanism.upgrade_level * 0.3)
  end

  def resolve(context)
    validate_inputs!(context)

    clicks = context[:elevation_clicks] || 0
    angle = clicks * @degrees_per_click + @accuracy_variance

    {
      angle_deg: angle.clamp(0, mechanism.modifiers['max_elevation'] || 90)
    }
  end

  def metadata
    {
      slot: :elevation_dial,
      control_type: :dial,
      input_key: :elevation_clicks,
      label: "Elevation",
      min: 0,
      max: ((mechanism.modifiers['max_elevation'] || 90) / @degrees_per_click).to_i,
      step: 1,
      unit: "clicks",
      conversion: "#{@degrees_per_click.round(2)}°/click"
    }
  end
end
```

#### 6. Concrete Example: Sight (Metadata Provider)

```ruby
# app/models/player_mechanisms/sight.rb
class PlayerMechanisms::Sight < PlayerMechanism
  def runtime_class
    PlayerMechanisms::SightRuntime
  end

  def input_keys
    [:initial_velocity, :angle_deg, :caliber_mm]  # For range calculation
  end

  def output_keys
    []  # Doesn't contribute to engine inputs
  end

  def priority
    90  # Execute late (needs final values)
  end

  # Modifiers: { type: "telescopic", accuracy: 0.9 }
end

class PlayerMechanisms::SightRuntime < Artillery::Mechanisms::RuntimeBase
  attr_reader :estimate_accuracy

  def initialize_runtime
    base_accuracy = mechanism.modifiers['accuracy'] || 0.5
    upgrade_bonus = mechanism.upgrade_level * 0.1

    @estimate_accuracy = [base_accuracy + upgrade_bonus, 1.0].min
  end

  def resolve(context)
    # Doesn't modify context, just reads for metadata generation
    {}
  end

  def metadata
    {
      slot: :sight,
      display_type: :assistance,
      label: "Sight",
      type: mechanism.modifiers['type']
    }
  end

  # Assistance calculation uses final context values
  def assistance_data(context)
    velocity = context[:initial_velocity] || 500
    angle_deg = context[:angle_deg] || 45

    # Calculate estimated range
    angle_rad = angle_deg * Math::PI / 180
    g = 9.81
    estimated_range = (velocity**2 * Math.sin(2 * angle_rad) / g)

    # Add error based on sight quality
    error_margin = estimated_range * (1.0 - @estimate_accuracy) * 0.2
    rng = Random.new(@random_seed + mechanism.id + context.hash)
    range_with_error = estimated_range + (rng.rand - 0.5) * error_margin * 2

    {
      estimated_range_m: range_with_error.round(0),
      sight_accuracy: (@estimate_accuracy * 100).round(0),
      estimated_angle: angle_deg.round(1)
    }
  end
end
```

#### 7. Concrete Example: Recoil System (Turn Order)

```ruby
# app/models/player_mechanisms/recoil_system.rb
class PlayerMechanisms::RecoilSystem < PlayerMechanism
  def runtime_class
    PlayerMechanisms::RecoilSystemRuntime
  end

  def input_keys
    [:initial_velocity]  # Recoil proportional to velocity
  end

  def output_keys
    [:angle_deg_variance, :deflection_deg_variance]  # Adds inaccuracy
  end

  def priority
    25  # After velocity calculated
  end

  # Modifiers: { type: "hydropneumatic", base_recovery_time: 2.5 }
end

class PlayerMechanisms::RecoilSystemRuntime < Artillery::Mechanisms::RuntimeBase
  attr_reader :recovery_time, :stability_factor

  def initialize_runtime
    rng = Random.new(@random_seed + mechanism.id)

    base_time = mechanism.modifiers['base_recovery_time'] || 3.0
    upgrade_reduction = mechanism.upgrade_level * 0.2

    @recovery_time = base_time * (1.0 - upgrade_reduction) * (0.95 + rng.rand * 0.1)
    @stability_factor = rng.rand  # For accuracy variance
  end

  def resolve(context)
    validate_inputs!(context)

    velocity = context[:initial_velocity]

    # Higher velocity = more recoil = more inaccuracy
    recoil_factor = velocity / 500.0  # Normalize to typical velocity

    angle_variance = (@stability_factor - 0.5) * recoil_factor * 0.5
    deflection_variance = (@stability_factor - 0.3) * recoil_factor * 0.3

    {
      angle_deg_variance: angle_variance,
      deflection_deg_variance: deflection_variance
    }
  end

  def turn_order_delay
    @recovery_time
  end

  def metadata
    {
      slot: :recoil_system,
      display_type: :info,
      label: "Recoil System",
      details: {
        type: mechanism.modifiers['type'],
        recovery_time: "#{@recovery_time.round(2)}s"
      }
    }
  end
end
```

#### 8. Pipeline Resolver

```ruby
# lib/artillery/mechanisms/pipeline_resolver.rb
module Artillery
  module Mechanisms
    class PipelineResolver
      attr_reader :runtimes, :player_input

      def initialize(runtimes, player_input)
        @runtimes = runtimes
        @player_input = player_input
      end

      def resolve
        # Initialize context with player input
        context = @player_input.dup

        # Sort runtimes by priority
        sorted_runtimes = @runtimes.sort_by { |r| r.mechanism.priority }

        # Execute pipeline
        sorted_runtimes.each do |runtime|
          contributions = runtime.resolve(context)
          context.merge!(contributions)
        end

        context
      end

      def ballistic_attributes
        context = resolve

        # Extract only keys needed by ballistic engine
        {
          angle_deg: context[:angle_deg] || 45,
          initial_velocity: context[:initial_velocity] || 500,
          shell_weight: context[:shell_weight] || 25,
          deflection_deg: context[:deflection_deg] || 0,
          area_of_effect: context[:area_of_effect] || 0,
          surface_area: context[:surface_area] || 0.05
        }
      end

      def turn_order_delay
        @runtimes.sum(&:turn_order_delay)
      end

      def ui_metadata
        @runtimes.map { |r| r.metadata }.reject(&:empty?)
      end

      def assistance_data
        context = resolve

        @runtimes
          .select { |r| r.respond_to?(:assistance_data) }
          .map { |r| r.assistance_data(context) }
          .reduce({}, :merge)
      end
    end
  end
end
```

### Database Schema

Same as Plan A.

### Pros

✅ **Explicit Dependencies** - Input/output keys make data flow transparent
✅ **Ordered Execution** - Priority system ensures correct calculation order
✅ **Simpler Merging** - No ad-hoc multiplier/offset logic; each stage owns its transformations
✅ **Testable Pipeline** - Can test individual stages in isolation
✅ **Self-Documenting** - Input/output keys serve as interface contracts
✅ **Reduced Coupling** - Later stages can read earlier stage outputs naturally

### Cons

❌ **Priority Management** - Requires careful priority assignment to avoid bugs
❌ **Naming Conflicts** - Multiple mechanisms can't output same key (need conventions like `base_` prefix)
❌ **Opaque to Developers** - Pipeline execution order not immediately obvious from code
❌ **Limited Parallelism** - Sequential execution prevents concurrent resolution
❌ **Context Pollution** - Context hash grows large with all intermediate values

### Usage Example

```ruby
# Match setup (same as Plan A)
runtimes = loadout.player_mechanisms.map do |mech|
  mech.to_runtime(match: match, random_seed: match.random_seed)
end

# Turn submission
player_input = { elevation_clicks: 15, powder_charges: 3, deflection_clicks: 2 }
resolver = Artillery::Mechanisms::PipelineResolver.new(runtimes, player_input)

# Resolve pipeline (happens automatically in ballistic_attributes)
ballistic_attrs = resolver.ballistic_attributes

# Simulate
engine = Artillery::Engines::Ballistic3D.new(...)
result = engine.simulate(Artillery::Engines::Inputs::Ballistic3D.new(**ballistic_attrs))

# Turn order
next_turn_time = Time.current + resolver.turn_order_delay
```

---

## Design Plan C: Capability/Interface Architecture

### Philosophy

Mechanisms are **capability providers** that implement specific interfaces (e.g., `ProjectileLauncher`, `AimingDevice`, `LoadingMechanism`). The system uses **Duck Typing** and capability detection rather than explicit concern modules. This reduces boilerplate while maintaining flexibility.

### Core Structure

#### 1. Mechanism Base Class

```ruby
# app/models/player_mechanism.rb
class PlayerMechanism < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots
  has_many :player_loadouts, through: :player_loadout_slots

  self.inheritance_column = 'type'

  # Common attributes: type, slot_key, upgrade_level, modifiers, base_cost, base_weight

  def to_runtime(match:, random_seed:)
    runtime_class.new(
      mechanism: self,
      match: match,
      random_seed: random_seed
    )
  end

  def runtime_class
    raise NotImplementedError
  end

  # Query capabilities (duck typing friendly)
  def capabilities
    runtime_class.included_modules.map(&:name).grep(/Capability/)
  end
end
```

#### 2. Capability Definitions (Duck-Typed Interfaces)

```ruby
# lib/artillery/capabilities.rb
module Artillery
  module Capabilities
    # Mechanisms that affect projectile launch physics
    module ProjectileLauncher
      # @param state [Hash] Accumulated ballistic state
      # @return [Hash] Modifications to launch parameters
      def modify_launch(state)
        {}
      end
    end

    # Mechanisms that convert player input to aim parameters
    module AimingDevice
      # @param raw_input [Hash] Player's raw input
      # @return [Hash] Aiming parameters (angle, deflection, etc.)
      def aim(raw_input)
        {}
      end
    end

    # Mechanisms that affect loading/firing cycle time
    module LoadingMechanism
      # @return [Float] Time in seconds for loading cycle
      def loading_time
        0.0
      end
    end

    # Mechanisms that provide player assistance/information
    module AssistanceProvider
      # @param state [Hash] Current ballistic state
      # @return [Hash] Assistance data for UI
      def provide_assistance(state)
        {}
      end
    end

    # Mechanisms that contribute UI controls
    module UIControl
      # @return [Hash] Control metadata for rendering
      def control_spec
        {}
      end
    end

    # Mechanisms that modify physics engine configuration
    module EngineModifier
      # @return [Array] Affectors to add
      def affectors
        []
      end

      # @return [Array] Hooks to add
      def hooks
        []
      end
    end
  end
end
```

#### 3. Concrete Example: Cartridge

```ruby
# app/models/player_mechanisms/cartridge.rb
class PlayerMechanisms::Cartridge < PlayerMechanism
  def runtime_class
    PlayerMechanisms::CartridgeRuntime
  end
end

class PlayerMechanisms::CartridgeRuntime
  include Artillery::Capabilities::ProjectileLauncher
  include Artillery::Capabilities::UIControl

  attr_reader :mechanism, :match, :velocity_base, :weight, :surface_area

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism
    @match = match

    rng = Random.new(random_seed + mechanism.id)

    # Calculate randomized launch parameters
    @velocity_base = (mechanism.modifiers['base_velocity'] || 400) * (0.95 + rng.rand * 0.1)
    @velocity_per_charge = mechanism.modifiers['velocity_per_charge'] || 50
    @weight = (mechanism.modifiers['shell_weight_kg'] || 8.4) * (0.98 + rng.rand * 0.04)

    caliber_m = (mechanism.modifiers['caliber_mm'] || 84.5) / 1000.0
    @surface_area = Math::PI * (caliber_m / 2) ** 2
  end

  def modify_launch(state)
    # Read player input from state
    charges = state[:powder_charges] || 1

    velocity = @velocity_base + charges * @velocity_per_charge

    {
      initial_velocity: velocity,
      shell_weight: @weight,
      surface_area: @surface_area
    }
  end

  def control_spec
    {
      type: :slider,
      key: :powder_charges,
      label: "Powder Charges",
      min: 1,
      max: 5,
      default: 2,
      unit: "charges"
    }
  end
end
```

#### 4. Concrete Example: Barrel

```ruby
# app/models/player_mechanisms/barrel.rb
class PlayerMechanisms::Barrel < PlayerMechanism
  def runtime_class
    PlayerMechanisms::BarrelRuntime
  end
end

class PlayerMechanisms::BarrelRuntime
  include Artillery::Capabilities::ProjectileLauncher

  attr_reader :mechanism, :velocity_multiplier, :accuracy_offset

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism

    rng = Random.new(random_seed + mechanism.id)

    base_mult = mechanism.modifiers['velocity_multiplier'] || 1.0
    upgrade_bonus = 1.0 + mechanism.upgrade_level * 0.02
    wear = 0.95 + rng.rand * 0.1

    @velocity_multiplier = base_mult * upgrade_bonus * wear
    @accuracy_offset = (rng.rand - 0.5) * (1.0 - mechanism.upgrade_level * 0.1)
  end

  def modify_launch(state)
    # Multiply existing velocity, add accuracy variance
    {
      initial_velocity: (state[:initial_velocity] || 500) * @velocity_multiplier,
      angle_deg: (state[:angle_deg] || 45) + @accuracy_offset
    }
  end
end
```

#### 5. Concrete Example: Elevation Dial

```ruby
# app/models/player_mechanisms/elevation_dial.rb
class PlayerMechanisms::ElevationDial < PlayerMechanism
  def runtime_class
    PlayerMechanisms::ElevationDialRuntime
  end
end

class PlayerMechanisms::ElevationDialRuntime
  include Artillery::Capabilities::AimingDevice
  include Artillery::Capabilities::UIControl

  attr_reader :mechanism, :degrees_per_click

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism

    rng = Random.new(random_seed + mechanism.id)

    base_dpc = mechanism.modifiers['degrees_per_click'] || 2.0
    precision = 1.0 - mechanism.upgrade_level * 0.05

    @degrees_per_click = base_dpc * precision * (0.98 + rng.rand * 0.04)
  end

  def aim(raw_input)
    clicks = raw_input[:elevation_clicks] || 0
    angle = clicks * @degrees_per_click

    {
      angle_deg: angle.clamp(0, mechanism.modifiers['max_elevation'] || 90)
    }
  end

  def control_spec
    {
      type: :dial,
      key: :elevation_clicks,
      label: "Elevation",
      min: 0,
      max: ((mechanism.modifiers['max_elevation'] || 90) / @degrees_per_click).to_i,
      unit: "clicks",
      conversion: "#{@degrees_per_click.round(2)}°/click"
    }
  end
end
```

#### 6. Concrete Example: Sight

```ruby
# app/models/player_mechanisms/sight.rb
class PlayerMechanisms::Sight < PlayerMechanism
  def runtime_class
    PlayerMechanisms::SightRuntime
  end
end

class PlayerMechanisms::SightRuntime
  include Artillery::Capabilities::AssistanceProvider

  attr_reader :mechanism, :accuracy

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism
    @match = match

    base_acc = mechanism.modifiers['accuracy'] || 0.5
    upgrade_bonus = mechanism.upgrade_level * 0.1

    @accuracy = [base_acc + upgrade_bonus, 1.0].min
  end

  def provide_assistance(state)
    velocity = state[:initial_velocity] || 500
    angle_deg = state[:angle_deg] || 45

    # Calculate range estimate
    angle_rad = angle_deg * Math::PI / 180
    g = 9.81
    true_range = (velocity**2 * Math.sin(2 * angle_rad) / g)

    error = true_range * (1.0 - @accuracy) * 0.2
    estimated_range = true_range + (rand - 0.5) * error * 2

    {
      estimated_range_m: estimated_range.round(0),
      sight_accuracy_pct: (@accuracy * 100).round(0),
      wind_hint: "Light crosswind from West"
    }
  end
end
```

#### 7. Concrete Example: Recoil System

```ruby
# app/models/player_mechanisms/recoil_system.rb
class PlayerMechanisms::RecoilSystem < PlayerMechanism
  def runtime_class
    PlayerMechanisms::RecoilSystemRuntime
  end
end

class PlayerMechanisms::RecoilSystemRuntime
  include Artillery::Capabilities::LoadingMechanism
  include Artillery::Capabilities::ProjectileLauncher

  attr_reader :mechanism, :recovery_time

  def initialize(mechanism:, match:, random_seed:)
    @mechanism = mechanism

    rng = Random.new(random_seed + mechanism.id)

    base_time = mechanism.modifiers['recovery_time'] || 3.0
    upgrade_reduction = mechanism.upgrade_level * 0.2

    @recovery_time = base_time * (1.0 - upgrade_reduction) * (0.95 + rng.rand * 0.1)
  end

  def loading_time
    @recovery_time
  end

  def modify_launch(state)
    # Add recoil-induced inaccuracy
    velocity = state[:initial_velocity] || 500
    recoil_factor = velocity / 500.0

    {
      angle_deg: (state[:angle_deg] || 45) + (rand - 0.5) * recoil_factor * 0.5,
      deflection_deg: (state[:deflection_deg] || 0) + (rand - 0.5) * recoil_factor * 0.3
    }
  end
end
```

#### 8. Capability Resolver

```ruby
# lib/artillery/mechanisms/capability_resolver.rb
module Artillery
  module Mechanisms
    class CapabilityResolver
      attr_reader :runtimes, :raw_input

      def initialize(runtimes, raw_input)
        @runtimes = runtimes
        @raw_input = raw_input
      end

      def resolve
        state = @raw_input.dup

        # Phase 1: Aiming devices convert raw input to aim parameters
        aimers = select_capability(Capabilities::AimingDevice)
        aimers.each do |aimer|
          state.merge!(aimer.aim(@raw_input))
        end

        # Phase 2: Launchers modify launch parameters
        launchers = select_capability(Capabilities::ProjectileLauncher)
        launchers.each do |launcher|
          state.merge!(launcher.modify_launch(state))
        end

        state
      end

      def ballistic_attributes
        state = resolve

        {
          angle_deg: state[:angle_deg] || 45,
          initial_velocity: state[:initial_velocity] || 500,
          shell_weight: state[:shell_weight] || 25,
          deflection_deg: state[:deflection_deg] || 0,
          area_of_effect: state[:area_of_effect] || 0,
          surface_area: state[:surface_area] || 0.05
        }
      end

      def turn_order_delay
        loaders = select_capability(Capabilities::LoadingMechanism)
        loaders.sum(&:loading_time)
      end

      def ui_controls
        controls = select_capability(Capabilities::UIControl)
        controls.map(&:control_spec)
      end

      def assistance_data
        state = resolve
        assistants = select_capability(Capabilities::AssistanceProvider)
        assistants.map { |a| a.provide_assistance(state) }.reduce({}, :merge)
      end

      def engine_affectors
        modifiers = select_capability(Capabilities::EngineModifier)
        modifiers.flat_map(&:affectors)
      end

      def engine_hooks
        modifiers = select_capability(Capabilities::EngineModifier)
        modifiers.flat_map(&:hooks)
      end

      private

      def select_capability(capability_module)
        @runtimes.select { |r| r.is_a?(capability_module) }
      end
    end
  end
end
```

### Database Schema

Same as Plan A.

### Pros

✅ **Minimal Boilerplate** - No explicit concern declarations, just include modules
✅ **Duck Typing Friendly** - Capability detection via `is_a?` checks
✅ **Flexible Composition** - Mechanisms implement only needed capabilities
✅ **Easy to Add Capabilities** - New capability modules don't require base class changes
✅ **Clear Phases** - Resolver has explicit phases (aiming → launching)
✅ **Ruby Idiomatic** - Leverages Ruby's module system naturally

### Cons

❌ **Less Explicit** - No declared input/output keys; method signatures define contracts
❌ **State Mutation** - Mechanisms mutate shared state hash (can cause subtle bugs)
❌ **Order-Dependent** - Within phases, execution order matters but isn't enforced
❌ **Limited Type Safety** - Duck typing can hide interface mismatches until runtime
❌ **Testing Complexity** - Need to mock entire state hash for isolation tests

### Usage Example

```ruby
# Match setup (same as previous plans)
runtimes = loadout.player_mechanisms.map do |mech|
  mech.to_runtime(match: match, random_seed: match.random_seed)
end

# Turn submission
raw_input = { elevation_clicks: 15, powder_charges: 3, deflection_clicks: 2 }
resolver = Artillery::Mechanisms::CapabilityResolver.new(runtimes, raw_input)

# Simulate
ballistic_attrs = resolver.ballistic_attributes
engine = Artillery::Engines::Ballistic3D.new(
  affectors: [*default_affectors, *resolver.engine_affectors],
  before_tick_hooks: resolver.engine_hooks
)
result = engine.simulate(Artillery::Engines::Inputs::Ballistic3D.new(**ballistic_attrs))

# UI and turn order
controls = resolver.ui_controls
assistance = resolver.assistance_data
next_turn_time = Time.current + resolver.turn_order_delay
```

---

## Comparative Analysis

| Aspect | Plan A: Multi-Concern | Plan B: Pipeline | Plan C: Capability |
|--------|----------------------|------------------|-------------------|
| **Boilerplate** | High (concern modules) | Medium (input/output keys) | Low (duck typing) |
| **Explicitness** | Very explicit | Explicit via keys | Implicit |
| **Flexibility** | High | Medium | Very high |
| **Type Safety** | Medium (module checks) | Low (hash keys) | Low (duck typing) |
| **Testability** | Excellent (isolated concerns) | Good (pipeline stages) | Fair (state mocking) |
| **Learning Curve** | Steep | Medium | Gentle |
| **Debugging** | Clear (concern boundaries) | Medium (pipeline trace) | Hard (state mutations) |
| **Extensibility** | Excellent | Good | Excellent |
| **Order Management** | N/A (parallel) | Required (priority) | Phase-based |
| **Cross-Dependencies** | Explicit (resolver) | Natural (context flow) | Natural (state flow) |

---

## Final Architectural Decision

### **SELECTED: Plan B (Pipeline/Resolver) + UI Option 1 (Metadata-Driven ViewComponents)**

After careful analysis of project requirements and constraints, this hybrid approach has been selected as the official architecture for the Artillery mechanism system.

---

## Rationale for Plan B (Pipeline/Resolver)

### Why Pipeline Architecture?

1. **Clear Data Flow** - Input/output keys make dependencies explicit and self-documenting
2. **Ordered Execution** - Priority system handles complex dependencies naturally (e.g., cartridge → barrel → sight)
3. **Balanced Complexity** - More structure than Plan C, less boilerplate than Plan A
4. **Testable** - Each pipeline stage can be tested independently with mock context
5. **Extensible** - Adding new mechanisms doesn't require modifying resolver logic
6. **Suitable for QF 18-Pounder** - The platform has clear dependency chains (cartridge provides base values, barrel/recoil modify them, sight reads final values)

### Why Not Plan A (Multi-Concern)?

While Plan A is the most robust long-term architecture, its **verbosity and steep learning curve** make it suboptimal for getting the QF 18-Pounder playable quickly. The concern module system adds significant boilerplate for minimal practical benefit at this scale.

**When to Reconsider:** If the mechanism system grows beyond 15-20 mechanism types or if cross-cutting concerns become dominant.

### Why Not Plan C (Capability)?

Plan C's duck-typed capability detection is **too implicit** for a system with complex data dependencies. The lack of declared input/output contracts makes debugging difficult and increases the risk of subtle ordering bugs.

**When to Use:** Rapid prototyping of experimental mechanisms before formalizing their contracts.

---

## Priority Management Solution

### MechanismOrderer Pattern

Rather than hardcoding priority logic into the resolver, we introduce a **dedicated ordering component** that provides:

- **Single Responsibility**: One class handles all mechanism ordering logic
- **Easy Testing**: Isolated component for unit testing ordering rules
- **Extensibility**: Simple entry point for complex ordering if needed
- **Simplicity**: Most platforms have 7-10 mechanisms, so `ORDER BY priority` suffices

#### Implementation

```ruby
# lib/artillery/mechanisms/mechanism_orderer.rb
module Artillery
  module Mechanisms
    class MechanismOrderer
      attr_reader :runtimes

      def initialize(runtimes)
        @runtimes = runtimes
      end

      # Default implementation: simple priority-based ordering
      def ordered
        @runtimes.sort_by { |runtime| runtime.mechanism.priority }
      end

      # Future extension point for complex ordering
      # Example: topological sort based on declared dependencies
      def ordered_by_dependencies
        # Build dependency graph
        # Perform topological sort
        # Return ordered runtimes
      end

      # Future: detect circular dependencies
      def validate!
        # Check for dependency cycles
        # Raise error if detected
      end
    end
  end
end
```

#### Usage in Resolver

```ruby
# lib/artillery/mechanisms/pipeline_resolver.rb
module Artillery
  module Mechanisms
    class PipelineResolver
      attr_reader :runtimes, :player_input

      def initialize(runtimes, player_input)
        @runtimes = runtimes
        @player_input = player_input
        @orderer = MechanismOrderer.new(runtimes)
      end

      def resolve
        context = @player_input.dup

        # Delegate ordering to MechanismOrderer
        @orderer.ordered.each do |runtime|
          contributions = runtime.resolve(context)
          context.merge!(contributions)
        end

        context
      end

      # ... rest of resolver methods
    end
  end
end
```

#### Priority Range Guidelines

To minimize conflicts and allow easy insertion of new mechanisms:

| Priority Range | Purpose | Examples |
|----------------|---------|----------|
| **0-9** | Player input conversion | Elevation dial, deflection control |
| **10-19** | Base value providers | Cartridge (velocity, weight, area) |
| **20-29** | Primary modifiers | Barrel (velocity multiplier) |
| **30-39** | Secondary modifiers | Recoil system (accuracy variance) |
| **40-49** | Tertiary modifiers | Wind, temperature effects |
| **50-89** | Non-ballistic mechanics | Breech (loading time), carriage (weight) |
| **90-99** | Metadata/assistance | Sight (range estimates) |

**Spacing Strategy:** Use increments of 10 to leave room for future mechanisms without renumbering existing ones.

---

## Rationale for UI Option 1 (Metadata-Driven ViewComponents)

### Why Metadata-Driven Components?

1. **Rapid Development** - Get all mechanisms rendering quickly with minimal boilerplate
2. **Consistency** - All dials/sliders behave similarly, creating cohesive UX
3. **Perfect Pairing** - Metadata from pipeline resolver feeds directly into components
4. **Reusability** - One `DialComponent` handles elevation, deflection, and future dial-based mechanisms
5. **Tailwind-Friendly** - Component templates work naturally with utility classes
6. **Easy Enhancement** - Can selectively override specific mechanisms later with type-specific components

### Why Not Type-Specific Components (Option 2)?

Type-specific components create **excessive boilerplate** for mechanisms that differ only in ranges, labels, and units. For 9 QF 18-Pounder mechanisms, this would mean 9 component classes + templates + Stimulus controllers. Option 1 achieves the same with 4-5 generic families.

**When to Use:** Mechanisms with truly unique UI requirements (e.g., compound breech loading sequence, multi-axis rangefinder).

### Why Not Compound/Slots (Option 3)?

Compound components with slots are **overkill** for simple control panels. The `renders_many` API adds complexity without corresponding benefit at this scale.

**When to Use:** Complex layouts like match lobby, loadout builder, or multi-player control panels.

---

## Key Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Mechanism Architecture** | Plan B: Pipeline/Resolver | Clear data flow, explicit dependencies, balanced complexity |
| **Priority Management** | MechanismOrderer pattern | Single responsibility, easily testable, extensible entry point |
| **UI Architecture** | Option 1: Metadata-Driven | Rapid development, consistency, minimal boilerplate |
| **Priority Ranges** | 10-unit increments | Easy insertion without renumbering |
| **Naming Conventions** | `base_*`, `*_multiplier`, `*_offset` | Clear semantics for merging strategies |
| **Context Scope** | ~20 keys maximum | Prevents pollution, encourages encapsulation |

---

## Implementation Concerns Addressed

### Priority Management
- **Solution**: `MechanismOrderer` class with simple `ORDER BY priority`
- **Benefit**: Easy to test, easy to extend if topological sort needed later
- **Scale**: Handles 7-10 mechanisms per platform with ease

### Naming Conflicts
- **Solution**: Establish conventions (`base_*` for sources, `*_multiplier`/`*_offset` for modifiers)
- **Benefit**: Clear merge semantics in resolver
- **Example**: `base_initial_velocity` (cartridge) + `initial_velocity_multiplier` (barrel) = `initial_velocity`

### Context Growth
- **Solution**: Limit context to ~20 keys; extract subsets for assistance calculations
- **Benefit**: Prevents hash pollution, encourages encapsulation
- **Pattern**: Assistance data calculated separately, not mixed into ballistic context

### Cross-Mechanism Dependencies
- **Solution**: Pipeline stages declare `input_keys` and `output_keys`
- **Benefit**: Dependencies are explicit and verifiable
- **Future**: `MechanismOrderer` can validate dependency graph if needed

---

## Migration Path

### Phase 1: Core Pipeline (Immediate)
1. Implement `PlayerMechanism` base class with STI
2. Create `MechanismOrderer` for priority-based ordering
3. Build `PipelineResolver` with context merging logic
4. Define priority ranges and naming conventions

### Phase 2: QF 18-Pounder Mechanisms (Sprint 1)
1. Implement mechanism runtimes (Cartridge, Barrel, Elevation Dial, etc.)
2. Define `input_keys`, `output_keys`, `priority` for each
3. Write unit tests for individual mechanisms
4. Write integration tests for full pipeline

### Phase 3: ViewComponents (Sprint 2)
1. Install `view_component` gem
2. Create `MechanismComponent` base and component factory
3. Build `DialComponent`, `SliderComponent`, `InfoDisplayComponent`
4. Implement Stimulus controllers for interactivity
5. Write component tests

### Phase 4: Controllers & Views (Sprint 3)
1. Build `MatchesController` with runtime instantiation
2. Build `TurnsController` with resolver integration
3. Design Tailwind theme for artillery controls
4. Wire up Turbo Frames for live updates

---

## Why This Architecture Will Scale

1. **Modular Mechanisms** - New artillery platforms reuse existing mechanism types
2. **Isolated Ordering** - `MechanismOrderer` can be enhanced without touching mechanisms
3. **Component Reuse** - UI components work for any platform with similar control types
4. **Clear Contracts** - Input/output keys make dependencies explicit
5. **Testable** - Each layer (mechanism, orderer, resolver, component) tests independently
6. **Extensible** - Can add topological sort, dependency validation, or custom components later

---

## Alternatives Considered (For Future Reference)

### Plan A (Multi-Concern): When to Reconsider
- System grows beyond 15-20 mechanism types
- Cross-cutting concerns (logging, caching, analytics) become dominant
- Multiple teams working on mechanism system simultaneously

### Plan C (Capability): When to Use
- Rapid prototyping of experimental mechanisms
- Quick validation of game design ideas
- Throwaway code for playtesting

### Type-Specific UI Components: When to Use
- Mechanisms with truly unique interfaces (e.g., 3D trajectory planner)
- Heavy client-side interactivity (e.g., drag-and-drop shell loading)
- Platform-specific branding (e.g., steampunk vs. modern aesthetic)

---

## ViewComponent UI Architecture

### Overview

Using the [ViewComponent](https://viewcomponent.org/) library, we can create a family of reusable UI components that render mechanism controls programmatically based on metadata from the mechanism runtime. This approach provides:

- **Type Safety** - Components are Ruby classes with explicit interfaces
- **Reusability** - One component family handles all variants of a mechanism type
- **Testability** - Components can be unit tested independently
- **Server-Side Rendering** - Integrates perfectly with Turbo/Hotwire for live updates
- **Maintainability** - Control rendering logic lives in one place, not scattered across views

### Component Family Architecture

#### Core Concept

Each **mechanism family** (dials, sliders, info displays, etc.) gets a corresponding ViewComponent that:

1. Accepts mechanism runtime metadata as initialization parameters
2. Renders appropriate HTML/CSS/Stimulus controllers based on metadata
3. Handles input validation and formatting
4. Provides accessibility features (ARIA labels, keyboard navigation)

#### Component Hierarchy

```
MechanismComponent (Base)
├── DialComponent (rotary controls: elevation, deflection)
├── SliderComponent (linear controls: powder charges, range finder)
├── ToggleComponent (discrete options: fuse type, shell type)
├── InfoDisplayComponent (read-only: barrel specs, carriage weight)
├── AssistanceComponent (calculated helpers: sight estimates, wind indicators)
└── CompoundComponent (multiple sub-controls: breech loading sequence)
```

---

### Design Option 1: Metadata-Driven Components

**Philosophy:** Components interrogate runtime metadata and render accordingly.

#### Base Component

```ruby
# app/components/mechanism_component.rb
class MechanismComponent < ViewComponent::Base
  attr_reader :runtime, :metadata, :current_value

  def initialize(runtime:, current_value: nil)
    @runtime = runtime
    @metadata = runtime.metadata
    @current_value = current_value || metadata[:default]
  end

  # Override in subclasses
  def render?
    metadata.present?
  end

  # Stimulus controller for this component
  def stimulus_controller
    "mechanism-#{component_type}"
  end

  def component_type
    metadata[:control_type] || :unknown
  end

  # Input name for form submission
  def input_name
    "turn_input[#{metadata[:input_key]}]"
  end

  # HTML ID for targeting
  def input_id
    "mechanism_#{runtime.mechanism.slot_key}"
  end
end
```

#### Dial Component

```ruby
# app/components/dial_component.rb
class DialComponent < MechanismComponent
  def render?
    component_type == :dial
  end

  def min_value
    metadata[:min] || 0
  end

  def max_value
    metadata[:max] || 100
  end

  def step
    metadata[:step] || 1
  end

  def unit_label
    metadata[:unit] || ""
  end

  def conversion_text
    metadata[:conversion] || ""
  end

  # Visual properties
  def tick_marks
    (min_value..max_value).step(step * 5).to_a
  end

  def major_tick_interval
    (max_value - min_value) / 10
  end
end
```

```erb
<!-- app/components/dial_component.html.erb -->
<div class="mechanism-dial"
     data-controller="<%= stimulus_controller %>"
     data-mechanism-dial-min-value="<%= min_value %>"
     data-mechanism-dial-max-value="<%= max_value %>"
     data-mechanism-dial-step-value="<%= step %>">

  <div class="dial-label">
    <label for="<%= input_id %>"><%= metadata[:label] %></label>
    <span class="conversion-hint"><%= conversion_text %></span>
  </div>

  <div class="dial-visual">
    <svg viewBox="0 0 200 200" class="dial-face">
      <!-- Background circle -->
      <circle cx="100" cy="100" r="80" class="dial-background" />

      <!-- Tick marks -->
      <% tick_marks.each_with_index do |value, idx| %>
        <% angle = 135 + (270.0 * (value - min_value) / (max_value - min_value)) %>
        <% is_major = (value % major_tick_interval == 0) %>
        <line
          x1="<%= 100 + 70 * Math.cos(angle * Math::PI / 180) %>"
          y1="<%= 100 + 70 * Math.sin(angle * Math::PI / 180) %>"
          x2="<%= 100 + (is_major ? 60 : 65) * Math.cos(angle * Math::PI / 180) %>"
          y2="<%= 100 + (is_major ? 60 : 65) * Math.sin(angle * Math::PI / 180) %>"
          class="<%= is_major ? 'tick-major' : 'tick-minor' %>" />

        <% if is_major %>
          <text x="<%= 100 + 50 * Math.cos(angle * Math::PI / 180) %>"
                y="<%= 100 + 50 * Math.sin(angle * Math::PI / 180) %>"
                class="tick-label"><%= value %></text>
        <% end %>
      <% end %>

      <!-- Pointer -->
      <line x1="100" y1="100"
            x2="100" y2="30"
            class="dial-pointer"
            data-mechanism-dial-target="pointer" />

      <!-- Center knob -->
      <circle cx="100" cy="100" r="8" class="dial-knob" />
    </svg>

    <!-- Current value display -->
    <div class="dial-readout" data-mechanism-dial-target="readout">
      <span class="value"><%= current_value %></span>
      <span class="unit"><%= unit_label %></span>
    </div>
  </div>

  <!-- Hidden input for form submission -->
  <input type="hidden"
         id="<%= input_id %>"
         name="<%= input_name %>"
         value="<%= current_value %>"
         data-mechanism-dial-target="input" />

  <!-- Adjustment buttons -->
  <div class="dial-controls">
    <button type="button"
            data-action="click->mechanism-dial#decrement"
            class="btn-dial-down">-</button>
    <button type="button"
            data-action="click->mechanism-dial#increment"
            class="btn-dial-up">+</button>
  </div>
</div>
```

#### Slider Component

```ruby
# app/components/slider_component.rb
class SliderComponent < MechanismComponent
  def render?
    component_type == :slider
  end

  def min_value
    metadata[:min] || 0
  end

  def max_value
    metadata[:max] || 10
  end

  def step
    metadata[:step] || 1
  end

  def unit_label
    metadata[:unit] || ""
  end

  # Visual markers
  def marker_values
    (min_value..max_value).step(step).to_a
  end
end
```

```erb
<!-- app/components/slider_component.html.erb -->
<div class="mechanism-slider"
     data-controller="<%= stimulus_controller %>">

  <div class="slider-label">
    <label for="<%= input_id %>"><%= metadata[:label] %></label>
  </div>

  <div class="slider-track">
    <!-- Markers -->
    <div class="slider-markers">
      <% marker_values.each do |value| %>
        <span class="marker" data-value="<%= value %>"><%= value %></span>
      <% end %>
    </div>

    <!-- Range input -->
    <input type="range"
           id="<%= input_id %>"
           name="<%= input_name %>"
           min="<%= min_value %>"
           max="<%= max_value %>"
           step="<%= step %>"
           value="<%= current_value %>"
           data-mechanism-slider-target="input"
           data-action="input->mechanism-slider#update"
           class="slider-input" />

    <!-- Current value display -->
    <div class="slider-value" data-mechanism-slider-target="display">
      <span class="value"><%= current_value %></span>
      <span class="unit"><%= unit_label %></span>
    </div>
  </div>
</div>
```

#### Info Display Component

```ruby
# app/components/info_display_component.rb
class InfoDisplayComponent < MechanismComponent
  def render?
    metadata[:display_type] == :info
  end

  def details
    metadata[:details] || {}
  end
end
```

```erb
<!-- app/components/info_display_component.html.erb -->
<div class="mechanism-info">
  <div class="info-label"><%= metadata[:label] %></div>

  <dl class="info-details">
    <% details.each do |key, value| %>
      <div class="detail-row">
        <dt><%= key.to_s.humanize %></dt>
        <dd><%= value %></dd>
      </div>
    <% end %>
  </dl>
</div>
```

#### Assistance Component

```ruby
# app/components/assistance_component.rb
class AssistanceComponent < MechanismComponent
  attr_reader :assistance_data

  def initialize(runtime:, assistance_data:)
    super(runtime: runtime)
    @assistance_data = assistance_data
  end

  def render?
    metadata[:display_type] == :assistance && assistance_data.present?
  end
end
```

```erb
<!-- app/components/assistance_component.html.erb -->
<div class="mechanism-assistance" data-controller="mechanism-assistance">
  <div class="assistance-header">
    <h4><%= metadata[:label] %></h4>
    <span class="sight-type"><%= metadata[:type] %></span>
  </div>

  <div class="assistance-data">
    <% if assistance_data[:estimated_range_m] %>
      <div class="assistance-item">
        <span class="label">Estimated Range:</span>
        <span class="value"><%= assistance_data[:estimated_range_m] %>m</span>
        <span class="accuracy">
          (±<%= (100 - assistance_data[:sight_accuracy_pct]).round %>% error)
        </span>
      </div>
    <% end %>

    <% if assistance_data[:estimated_angle] %>
      <div class="assistance-item">
        <span class="label">Calculated Angle:</span>
        <span class="value"><%= assistance_data[:estimated_angle] %>°</span>
      </div>
    <% end %>

    <% if assistance_data[:wind_hint] %>
      <div class="assistance-item wind-hint">
        <span class="label">Wind Correction:</span>
        <span class="value"><%= assistance_data[:wind_hint] %></span>
      </div>
    <% end %>
  </div>
</div>
```

#### Component Factory

```ruby
# app/components/mechanism_component_factory.rb
class MechanismComponentFactory
  COMPONENT_MAP = {
    dial: DialComponent,
    slider: SliderComponent,
    toggle: ToggleComponent,
    info: InfoDisplayComponent,
    assistance: AssistanceComponent
  }.freeze

  def self.for(runtime:, current_value: nil, assistance_data: nil)
    metadata = runtime.metadata
    control_type = metadata[:control_type]&.to_sym
    display_type = metadata[:display_type]&.to_sym

    component_class = COMPONENT_MAP[control_type] || COMPONENT_MAP[display_type]

    return nil unless component_class

    if component_class == AssistanceComponent
      component_class.new(runtime: runtime, assistance_data: assistance_data)
    else
      component_class.new(runtime: runtime, current_value: current_value)
    end
  end
end
```

#### View Usage

```erb
<!-- app/views/matches/show.html.erb -->
<%= turbo_frame_tag "turn-controls" do %>
  <div class="artillery-controls">
    <% @mechanism_runtimes.each do |runtime| %>
      <% component = MechanismComponentFactory.for(
           runtime: runtime,
           current_value: @current_input[runtime.mechanism.slot_key],
           assistance_data: @resolver.assistance_data
         ) %>

      <% if component %>
        <%= render component %>
      <% end %>
    <% end %>

    <button type="submit" class="btn-fire">Fire!</button>
  </div>
<% end %>
```

### Stimulus Controllers

Each component needs a Stimulus controller for interactivity:

```javascript
// app/javascript/controllers/mechanism_dial_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "pointer", "readout"]
  static values = {
    min: Number,
    max: Number,
    step: Number
  }

  connect() {
    this.updateVisual()
  }

  increment() {
    const current = parseInt(this.inputTarget.value)
    const next = Math.min(current + this.stepValue, this.maxValue)
    this.inputTarget.value = next
    this.updateVisual()
  }

  decrement() {
    const current = parseInt(this.inputTarget.value)
    const next = Math.max(current - this.stepValue, this.minValue)
    this.inputTarget.value = next
    this.updateVisual()
  }

  updateVisual() {
    const value = parseInt(this.inputTarget.value)
    const range = this.maxValue - this.minValue
    const percent = (value - this.minValue) / range

    // Rotate pointer (135° to 405° range for 270° arc)
    const angle = 135 + (percent * 270)
    this.pointerTarget.setAttribute(
      "transform",
      `rotate(${angle} 100 100)`
    )

    // Update readout
    this.readoutTarget.querySelector(".value").textContent = value
  }
}
```

```javascript
// app/javascript/controllers/mechanism_slider_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display"]

  update() {
    const value = this.inputTarget.value
    this.displayTarget.querySelector(".value").textContent = value
  }
}
```

---

### Design Option 2: Type-Specific Components

**Philosophy:** Each mechanism type gets a dedicated component tailored to its needs.

#### Elevation Dial Component

```ruby
# app/components/mechanisms/elevation_dial_component.rb
module Mechanisms
  class ElevationDialComponent < ViewComponent::Base
    attr_reader :runtime, :current_clicks

    def initialize(runtime:, current_clicks: 0)
      @runtime = runtime
      @current_clicks = current_clicks
    end

    def degrees_per_click
      runtime.degrees_per_click
    end

    def max_clicks
      (runtime.mechanism.modifiers['max_elevation'] / degrees_per_click).to_i
    end

    def current_angle
      (current_clicks * degrees_per_click).round(1)
    end

    def estimated_range
      # Could call runtime method if available
      velocity = 500 # placeholder
      angle_rad = current_angle * Math::PI / 180
      (velocity**2 * Math.sin(2 * angle_rad) / 9.81).round(0)
    end
  end
end
```

```erb
<!-- app/components/mechanisms/elevation_dial_component.html.erb -->
<div class="elevation-dial-component" data-controller="elevation-dial">
  <div class="dial-header">
    <h3>Elevation Control</h3>
    <div class="current-reading">
      <span class="angle"><%= current_angle %>°</span>
      <span class="clicks">(<%= current_clicks %> clicks)</span>
    </div>
  </div>

  <!-- Custom dial visualization for elevation -->
  <div class="elevation-visual">
    <!-- SVG with quadrant markers, range arc overlays -->
    <%= render partial: "mechanisms/elevation_visual",
               locals: { angle: current_angle, max: 90 } %>
  </div>

  <input type="hidden"
         name="turn_input[elevation_clicks]"
         value="<%= current_clicks %>"
         data-elevation-dial-target="input" />

  <div class="dial-controls">
    <button data-action="click->elevation-dial#coarseDown">-10</button>
    <button data-action="click->elevation-dial#fineDown">-1</button>
    <button data-action="click->elevation-dial#fineUp">+1</button>
    <button data-action="click->elevation-dial#coarseUp">+10</button>
  </div>

  <div class="range-estimate">
    Estimated Range: ~<%= estimated_range %>m
    <span class="estimate-warning">(sight-dependent)</span>
  </div>
</div>
```

#### Powder Charge Slider Component

```ruby
# app/components/mechanisms/powder_charge_component.rb
module Mechanisms
  class PowderChargeComponent < ViewComponent::Base
    attr_reader :runtime, :current_charges

    def initialize(runtime:, current_charges: 2)
      @runtime = runtime
      @current_charges = current_charges
    end

    def min_charges
      1
    end

    def max_charges
      5
    end

    def velocity_at(charges)
      base = runtime.mechanism.modifiers['base_velocity'] || 400
      per_charge = runtime.mechanism.modifiers['velocity_per_charge'] || 50
      (base + charges * per_charge).round(0)
    end

    def recoil_warning?
      current_charges >= 4
    end
  end
end
```

```erb
<!-- app/components/mechanisms/powder_charge_component.html.erb -->
<div class="powder-charge-component" data-controller="powder-charge">
  <div class="charge-header">
    <h3>Powder Charges</h3>
    <div class="velocity-display">
      Est. Velocity: <%= velocity_at(current_charges) %> m/s
    </div>
  </div>

  <!-- Visual representation of charges (stacked cylinders?) -->
  <div class="charge-visual">
    <% (1..max_charges).each do |charge_num| %>
      <div class="charge-unit <%= 'active' if charge_num <= current_charges %>">
        <%= charge_num %>
      </div>
    <% end %>
  </div>

  <input type="range"
         name="turn_input[powder_charges]"
         min="<%= min_charges %>"
         max="<%= max_charges %>"
         value="<%= current_charges %>"
         data-powder-charge-target="input"
         data-action="input->powder-charge#update" />

  <% if recoil_warning? %>
    <div class="warning-message">
      ⚠️ High charges increase recoil and reduce accuracy
    </div>
  <% end %>
</div>
```

---

### Design Option 3: Compound Components with Slots

**Philosophy:** Use ViewComponent's `renders_many` / `renders_one` to compose complex mechanism UIs from smaller pieces.

```ruby
# app/components/artillery_control_panel_component.rb
class ArtilleryControlPanelComponent < ViewComponent::Base
  renders_many :mechanisms, types: {
    dial: DialComponent,
    slider: SliderComponent,
    info: InfoDisplayComponent,
    assistance: AssistanceComponent
  }

  renders_one :fire_button, FireButtonComponent

  attr_reader :loadout, :runtimes

  def initialize(loadout:, runtimes:)
    @loadout = loadout
    @runtimes = runtimes
  end
end
```

```erb
<!-- app/components/artillery_control_panel_component.html.erb -->
<div class="artillery-control-panel">
  <div class="panel-header">
    <h2><%= loadout.label %></h2>
    <span class="platform-type"><%= loadout.platform_type.humanize %></span>
  </div>

  <div class="mechanisms-grid">
    <% mechanisms.each do |mechanism_component| %>
      <div class="mechanism-slot">
        <%= mechanism_component %>
      </div>
    <% end %>
  </div>

  <div class="panel-footer">
    <%= fire_button || render(FireButtonComponent.new) %>
  </div>
</div>
```

Usage:

```erb
<!-- app/views/turns/new.html.erb -->
<%= render(ArtilleryControlPanelComponent.new(loadout: @loadout, runtimes: @runtimes)) do |panel| %>
  <% @runtimes.each do |runtime| %>
    <% case runtime.metadata[:control_type] %>
    <% when :dial %>
      <% panel.with_mechanism_dial(runtime: runtime, current_value: @input[runtime.mechanism.slot_key]) %>
    <% when :slider %>
      <% panel.with_mechanism_slider(runtime: runtime, current_value: @input[runtime.mechanism.slot_key]) %>
    <% end %>
  <% end %>

  <% panel.with_fire_button do %>
    <button type="submit" class="btn-fire-custom">FIRE!</button>
  <% end %>
<% end %>
```

---

### Integration with Design Plans

#### Plan A (Multi-Concern) Integration

```ruby
# In UIMetadataProvider concern
module Artillery::Mechanisms::Concerns::UIMetadataProvider
  def ui_component_class
    case ui_metadata[:control_type]
    when :dial then DialComponent
    when :slider then SliderComponent
    # ...
    end
  end

  def render_component(current_value: nil)
    ui_component_class.new(runtime: self, current_value: current_value)
  end
end

# In view
<% @runtimes.select { |r| r.is_a?(UIMetadataProvider) }.each do |runtime| %>
  <%= render runtime.render_component(current_value: @input[runtime.mechanism.slot_key]) %>
<% end %>
```

#### Plan B (Pipeline) Integration

```ruby
# Pipeline resolver exposes component factory method
class PipelineResolver
  def ui_components(current_input = {})
    @runtimes
      .select { |r| r.metadata[:control_type].present? }
      .map { |r| MechanismComponentFactory.for(runtime: r, current_value: current_input[r.mechanism.slot_key]) }
      .compact
  end
end

# In view
<% @resolver.ui_components(@current_input).each do |component| %>
  <%= render component %>
<% end %>
```

#### Plan C (Capability) Integration

```ruby
# In CapabilityResolver
def ui_components(current_input = {})
  controls = select_capability(Capabilities::UIControl)
  controls.map do |runtime|
    MechanismComponentFactory.for(
      runtime: runtime,
      current_value: current_input[runtime.mechanism.slot_key]
    )
  end.compact
end

# In view (same as Plan B)
<% @resolver.ui_components(@current_input).each do |component| %>
  <%= render component %>
<% end %>
```

---

### Styling with Tailwind

ViewComponents work seamlessly with Tailwind CSS:

```erb
<!-- app/components/dial_component.html.erb with Tailwind -->
<div class="flex flex-col items-center space-y-4 p-6 bg-gray-800 rounded-lg shadow-lg"
     data-controller="<%= stimulus_controller %>">

  <div class="text-center">
    <label class="text-lg font-semibold text-gray-100"><%= metadata[:label] %></label>
    <p class="text-sm text-gray-400"><%= conversion_text %></p>
  </div>

  <div class="relative w-48 h-48">
    <svg viewBox="0 0 200 200" class="w-full h-full">
      <!-- SVG content -->
    </svg>

    <div class="absolute bottom-0 left-1/2 transform -translate-x-1/2 text-center">
      <span class="text-3xl font-bold text-green-400" data-mechanism-dial-target="readout">
        <%= current_value %>
      </span>
      <span class="text-sm text-gray-400"><%= unit_label %></span>
    </div>
  </div>

  <div class="flex space-x-2">
    <button type="button"
            data-action="click->mechanism-dial#decrement"
            class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-md transition">
      -
    </button>
    <button type="button"
            data-action="click->mechanism-dial#increment"
            class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-md transition">
      +
    </button>
  </div>
</div>
```

---

### Testing ViewComponents

ViewComponents are easy to unit test:

```ruby
# spec/components/dial_component_spec.rb
require 'rails_helper'

RSpec.describe DialComponent, type: :component do
  let(:mechanism) { create(:player_mechanism, :elevation_dial) }
  let(:runtime) do
    double(
      mechanism: mechanism,
      metadata: {
        control_type: :dial,
        label: "Elevation",
        min: 0,
        max: 45,
        step: 1,
        unit: "clicks",
        conversion: "2° per click",
        input_key: :elevation_clicks
      }
    )
  end

  it "renders dial with correct range" do
    render_inline(DialComponent.new(runtime: runtime, current_value: 10))

    expect(page).to have_css('.mechanism-dial')
    expect(page).to have_text('Elevation')
    expect(page).to have_text('2° per click')
    expect(page).to have_css('input[value="10"]', visible: :hidden)
  end

  it "generates correct tick marks" do
    render_inline(DialComponent.new(runtime: runtime, current_value: 10))

    expect(page).to have_css('.tick-major', count: 5) # 0, 11.25, 22.5, 33.75, 45
  end

  it "includes increment/decrement buttons" do
    render_inline(DialComponent.new(runtime: runtime, current_value: 10))

    expect(page).to have_button('-')
    expect(page).to have_button('+')
  end
end
```

---

### Comparative Analysis of UI Options

| Aspect | Option 1: Metadata-Driven | Option 2: Type-Specific | Option 3: Compound/Slots |
|--------|---------------------------|------------------------|--------------------------|
| **Reusability** | Excellent (one component per family) | Low (one per mechanism) | Good (composable pieces) |
| **Customization** | Limited (metadata-bound) | Unlimited | High (slot overrides) |
| **Boilerplate** | Low | High | Medium |
| **Type Safety** | Low (metadata hash) | High (explicit classes) | Medium |
| **Flexibility** | Medium | High | Very High |
| **Maintenance** | Easy (centralized) | Hard (many files) | Medium |
| **Learning Curve** | Low | Medium | Steep |
| **Best For** | Quick MVP, uniform UIs | Highly custom UIs | Complex layouts |

---

### Recommendation (Confirmed as Final Decision)

**SELECTED: Option 1 (Metadata-Driven) - Official UI Architecture**

This decision aligns perfectly with the chosen Plan B (Pipeline/Resolver) backend architecture, as detailed in the "Final Architectural Decision" section above.

**Implementation Path:**

- Option 1 for all core mechanisms (elevation, deflection, powder charges, barrel, sight, etc.)
- Selective Option 2 components only for truly unique UIs requiring custom interaction patterns
- Option 3 reserved for complex multi-mechanism layouts (match lobby, loadout builder)

---

## Next Steps

1. **Implement Plan B (Pipeline)** for QF 18-Pounder mechanisms
2. **Install ViewComponent gem** (`gem 'view_component'`)
3. **Create base MechanismComponent** and component factory
4. **Build DialComponent & SliderComponent** with Stimulus controllers
5. **Create Seed Data** for default mechanism variants (standard barrel, iron sights, etc.)
6. **Build Match Controller** that instantiates runtimes from loadouts
7. **Implement Turn Controller** that uses PipelineResolver
8. **Write Component Tests** using ViewComponent test helpers
9. **Design Tailwind theme** for artillery controls (brass/steel aesthetic)
10. **Write Integration Tests** for full pipeline execution
11. **Document Priority Ranges** for future mechanism developers

---

**End of Design Document**