# Artillery Game - Architecture Documentation

**Project:** Artillery - Turn-Based Comedy Artillery Game
**Technology Stack:** Ruby on Rails 8.1.1, Hotwire (Turbo + Stimulus), Tailwind CSS, PostgreSQL
**Status:** Early Development (Physics Engine Complete, Game Layer In Progress)
**Last Updated:** 2025-11-15

---

## Table of Contents

1. [Overview](#1-overview)
2. [Technology Stack](#2-technology-stack)
3. [Project Structure](#3-project-structure)
4. [Physics Engine Architecture](#4-physics-engine-architecture)
5. [Impact & Damage System](#5-impact--damage-system)
6. [Component & Mechanism System](#6-component--mechanism-system)
7. [Game Flow](#7-game-flow)
8. [Rails Integration](#8-rails-integration)
9. [Domain Model](#9-domain-model)
10. [Design Patterns](#10-design-patterns)
11. [Testing Strategy](#11-testing-strategy)
12. [Key Architectural Decisions](#12-key-architectural-decisions)
13. [Development Roadmap](#13-development-roadmap)

---

## 1. Overview

Artillery is a web-hosted turn-based comedy game where players customize artillery pieces and take turns shooting at paper or wooden targets. The key twist: at the start of each game, random variance is applied to each component of a player's artillery, creating a contest of both mastery and adaptation.

### Core Concepts

- **Turn-Based Gameplay:** Players submit aiming parameters (elevation, powder charge, deflection)
- **Component Variance:** Each match randomizes mechanism performance within tolerance ranges
- **Physics Simulation:** Detailed 3D ballistic engine with realistic forces (gravity, drag, wind)
- **Loose Coupling:** Support for multiple engine types (ballistic, non-ballistic future options)
- **Progressive Upgrades:** Players improve mechanisms between matches
- **Real-Time Updates:** Hotwire/Turbo for live match state without full page reloads

---

## 2. Technology Stack

### Backend
- **Ruby on Rails 8.1.1** - Web framework
- **PostgreSQL** - Primary database
- **Zeitwerk** - Module autoloading for custom lib/ namespace
- **RSpec** - Testing framework
- **FactoryBot** - Test fixture generation

### Frontend
- **Hotwire Stack:**
  - **Turbo Rails** - Server-driven UI updates via Turbo Frames/Streams
  - **Stimulus JS** - Lightweight JavaScript framework for progressive enhancement
- **Tailwind CSS** - Utility-first CSS framework via `tailwindcss-rails`
- **Importmap** - Native ES module imports without bundling

### Infrastructure (Planned)
- **Solid Queue** - Background job processing (Rails 8 default)
- **Redis** - Session storage, caching
- **ActionCable** - WebSocket support for real-time match updates

---

## 3. Project Structure

```
artillery/
├── app/
│   ├── controllers/              # Rails HTTP controllers (minimal)
│   ├── models/                   # ActiveRecord domain models
│   │   └── mechanisms/           # Game component models (in progress)
│   ├── views/                    # ERB templates + Turbo Frames
│   ├── javascript/
│   │   └── controllers/          # Stimulus JS controllers
│   └── assets/
│       └── builds/               # Compiled Tailwind CSS
│
├── lib/
│   └── artillery/                # Custom game engine namespace
│       ├── engines/              # Physics & evaluation engines
│       │   ├── affectors/        # Force application (gravity, drag, wind)
│       │   ├── hooks/            # Flight event triggers (parachute, etc.)
│       │   ├── inputs/           # Engine parameter resolvers
│       │   ├── ballistic_3d.rb   # Main physics simulator
│       │   ├── damage_evaluator.rb
│       │   └── target_resolution.rb
│       └── physics/              # Low-level physics primitives
│           ├── vector.rb         # 3D vector mathematics
│           └── shot_state.rb     # Ballistic state container
│
├── spec/                         # RSpec test suite
│   ├── lib/artillery/            # Engine unit tests
│   ├── models/                   # Model tests (future)
│   └── spec_helper.rb            # Zeitwerk + FactoryBot config
│
├── config/
│   ├── initializers/zeitwerk_lib.rb  # Custom autoloading
│   ├── importmap.rb              # JavaScript module mapping
│   └── routes.rb                 # Application routes (empty)
│
├── ai_docs/
│   └── concept.md                # Architectural design document
│
└── db/
    └── schema.rb                 # Database schema (minimal)
```

### Namespace Organization

The project separates concerns across two primary namespaces:

1. **`app/models/`** - Rails-managed domain models (players, matches, mechanisms)
2. **`lib/artillery/`** - Pure Ruby game logic (physics, simulation, evaluation)

This separation ensures:
- Physics engines remain framework-agnostic and testable
- Game logic can be extracted/reused outside Rails if needed
- Clear boundary between persistence and computation

---

## 4. Physics Engine Architecture

The physics system is the heart of Artillery, providing deterministic, realistic ballistic simulation.

### 4.1 Core Components

#### Vector (`lib/artillery/physics/vector.rb`)

3D vector mathematics foundation for all physics calculations.

**Properties:**
- `x`, `y`, `z` - Cartesian coordinates

**Operations:**
```ruby
v1 + v2          # Vector addition
v1 - v2          # Vector subtraction
v * scalar       # Scalar multiplication
v / scalar       # Scalar division
v.magnitude      # Euclidean length
v.normalize      # Unit vector (magnitude = 1)
v.inverse        # Negation
v.scale(s)       # In-place scalar multiplication
v.dup            # Deep copy
```

**Design Notes:**
- Immutable by default (operations return new vectors)
- Mutable variants suffixed with `!` for performance-critical loops
- Used for position, velocity, acceleration throughout engine

---

#### ShotState (`lib/artillery/physics/shot_state.rb`)

Container for projectile state during flight simulation.

**Attributes:**
```ruby
time:           Float    # Simulation time elapsed (seconds)
mass:           Float    # Shell mass (kg)
surface_area:   Float    # Cross-sectional area (m²) for drag
position:       Vector   # Current XYZ location
velocity:       Vector   # Current velocity vector
acceleration:   Vector   # Current acceleration from forces
```

**Convenience Methods:**
```ruby
altitude        # Returns position.z (height above ground)
dup             # Deep copy for state history tracking
```

**Usage:**
- Created once per simulation with initial conditions
- Modified in-place during each physics tick
- Copied to history array for trajectory recording

---

### 4.2 Ballistic3D Engine (`lib/artillery/engines/ballistic_3d.rb`)

Main physics simulator implementing Euler integration.

#### Initialization

```ruby
engine = Artillery::Engines::Ballistic3D.new(
  affectors: [
    Artillery::Engines::Affectors::Gravity.new,
    Artillery::Engines::Affectors::AirResistance.new(air_density: 1.225),
    Artillery::Engines::Affectors::Wind.new(wind_vector: Vector.new(0.1, 0, 0))
  ],
  before_hooks: [
    Artillery::Engines::Hooks::Flight::Parachute.new(
      deploy_altitude: 50,
      deploy_after_time: 3.0
    )
  ]
)
```

#### Simulation Loop

**Per-Tick Process (TICK = 0.05 seconds):**

1. **Before-Tick Hooks** - Run conditional triggers (parachute deployment, proximity fuses)
2. **Apply Affectors** - Calculate and apply forces (gravity, drag, wind)
3. **Euler Integration:**
   ```ruby
   velocity += acceleration * dt
   position += velocity * dt
   ```
4. **After-Tick Hooks** - Post-integration behaviors (future extensibility)
5. **Record History** - Copy state to trace array
6. **Ground Check** - Exit when `position.z <= 0`

**Termination Conditions:**
- Ground impact (`position.z <= 0`)
- Configurable maximum simulation time (safety timeout)

#### Output Format

```ruby
{
  impact_xyz: [x, y, z],     # Final position coordinates
  flight_time: 12.35,        # Total time in air (seconds)
  trace: [                   # Array of ShotState snapshots
    { time: 0.0, position: [...], velocity: [...], ... },
    { time: 0.05, position: [...], velocity: [...], ... },
    # ...
  ]
}
```

#### Initial Conditions

**Input Resolution (`lib/artillery/engines/inputs/ballistic_3d.rb`):**

```ruby
inputs = Artillery::Engines::Ballistic3D::Inputs.from_resolver(
  angle_deg: 45,           # Elevation angle (0-90°)
  initial_velocity: 500,   # Muzzle velocity (m/s)
  shell_weight: 25,        # Projectile mass (kg)
  deflection_deg: 0,       # Horizontal offset (default: 0)
  area_of_effect: 0        # Blast radius (not used in ballistic calc)
)
```

**Velocity Decomposition:**

```ruby
# Convert angles to radians
angle_rad = angle_deg * Math::PI / 180
deflection_rad = deflection_deg * Math::PI / 180

# Calculate velocity components
vx = initial_velocity * Math.cos(angle_rad) * Math.cos(deflection_rad)
vy = initial_velocity * Math.cos(angle_rad) * Math.sin(deflection_rad)
vz = initial_velocity * Math.sin(angle_rad)

# Create initial state
ShotState.new(
  position: Vector.new(0, 0, 0),
  velocity: Vector.new(vx, vy, vz),
  acceleration: Vector.new(0, 0, 0),
  mass: shell_weight,
  surface_area: 0.05,  # Default ~0.05 m² (spherical shell)
  time: 0.0
)
```

---

### 4.3 Affectors (Force Application)

All affectors inherit from `Artillery::Engines::Affectors::Base` and implement the `call!` interface:

```ruby
def call!(state, dt)
  # Modify state.acceleration based on physics model
end
```

#### Gravity (`lib/artillery/engines/affectors/gravity.rb`)

**Model:** Constant downward acceleration

**Formula:**
```ruby
state.acceleration.z -= gravity
```

**Parameters:**
- `gravity` (default: 9.81 m/s²) - Acceleration due to gravity

**Notes:**
- Configurable for other planetary bodies (Moon: 1.62 m/s², Mars: 3.71 m/s²)
- Acts on Z-axis only (simplification: no altitude-based variation)

---

#### Air Resistance (`lib/artillery/engines/affectors/air_resistance.rb`)

**Model:** Quadratic drag force

**Formula:**
```ruby
F_drag = 0.5 * ρ * v² * Cd * A

# Acceleration = Force / mass
a_drag = F_drag / mass

# Direction: opposite to velocity
acceleration -= velocity.normalize * a_drag
```

**Parameters:**
- `air_density` (ρ, default: 1.225 kg/m³) - Air density at sea level
- `drag_coefficient` (Cd, default: 0.47) - Spherical/blunt projectile
- Surface area (A) - From `state.surface_area`
- Mass - From `state.mass`

**Optimizations:**
- Early return if velocity is zero (avoids divide-by-zero in normalization)

**Notes:**
- Realistic for subsonic projectiles
- Does not model transonic/supersonic regimes (future enhancement)

---

#### Wind (`lib/artillery/engines/affectors/wind.rb`)

**Model:** Constant acceleration proportional to surface area

**Formula:**
```ruby
acceleration += wind_vector * surface_area
```

**Parameters:**
- `wind_vector` - Vector representing wind acceleration per square meter of surface area

**Example:**
```ruby
# Wind of 0.5 m/s² per m² in +X direction
wind = Artillery::Engines::Affectors::Wind.new(
  wind_vector: Vector.new(0.5, 0, 0)
)

# Projectile with 2 m² surface area experiences 1.0 m/s² acceleration
```

**Notes:**
- Simple area-scaled model (not velocity-dependent)
- Future enhancement: crosswind velocity-dependent drag

---

### 4.4 Flight Hooks

Hooks allow conditional, state-aware behaviors during flight.

#### Base Class (`lib/artillery/engines/hooks/flight/flight_hook.rb`)

```ruby
class FlightHook
  def tick(state, dt)
    # Inspect state, conditionally modify velocity/acceleration
  end
end
```

**Design Philosophy:**
- Separate from affectors (which always apply forces)
- Enable event-driven behaviors (deploy parachute at altitude)
- Can modify state directly (e.g., velocity *= 0.3)

---

#### Parachute Hook (`lib/artillery/engines/hooks/flight/parachute.rb`)

**Purpose:** Deploy parachute mid-flight based on triggers

**Deployment Triggers (evaluated each tick):**

1. **Altitude-based:**
   ```ruby
   state.altitude <= deploy_altitude
   ```

2. **Time-based:**
   ```ruby
   state.time >= deploy_after_time
   ```

3. **Distance-based:**
   ```ruby
   (state.position - starting_position).magnitude >= deploy_after_distance
   ```

**Deployment Effect:**
```ruby
# Sudden drag: reduce velocity to 30% of original
state.velocity.scale!(0.3)
```

**State Tracking:**
- `deployed` flag prevents repeated activation
- `starting_position` cached at first tick for distance calculation

**Example Usage:**
```ruby
# Deploy parachute 3 seconds after launch OR when falling below 50m altitude
parachute = Artillery::Engines::Hooks::Flight::Parachute.new(
  deploy_altitude: 50,
  deploy_after_time: 3.0
)

engine = Artillery::Engines::Ballistic3D.new(
  affectors: [...],
  before_hooks: [parachute]
)
```

---

### 4.5 Design Strengths

1. **Modularity:** Add/remove affectors without modifying engine core
2. **Determinism:** Fixed time step ensures consistent replay
3. **Testability:** Each affector unit-tested in isolation
4. **Extensibility:** New physics models (spin, Magnus effect) plug in seamlessly
5. **Performance:** In-place vector operations (`scale!`) in hot loops

---

## 5. Impact & Damage System

After physics simulation completes, two engines evaluate results:

### 5.1 Target Resolution (`lib/artillery/engines/target_resolution.rb`)

**Purpose:** Determine which targets are hit and how severely.

**Interface:**
```ruby
results = Artillery::Engines::TargetResolution.evaluate(
  impact_xyz: [100, 50, 0],
  targets: [
    { position: [105, 52, 0], material: :paper },
    { position: [98, 48, 0], material: :wood }
  ],
  trace: simulation_trace  # Optional, for future trajectory-based hits
)
```

**Output Format:**
```ruby
[
  { target: {...}, result: :destroyed, distance: 5.4 },
  { target: {...}, result: :missed, distance: 12.3 }
]
```

#### Hit Classification Logic

**Distance Calculation:**
```ruby
distance = Math.sqrt(
  (target_x - impact_x)**2 +
  (target_y - impact_y)**2 +
  (target_z - impact_z)**2
)
```

**Material Response Table:**

| Material | Threshold | Result         |
|----------|-----------|----------------|
| Paper    | ≤ 5m      | `:destroyed`   |
| Paper    | > 5m      | `:missed`      |
| Wood     | ≤ 2m      | `:damaged`     |
| Wood     | > 2m      | `:missed`      |
| Metal    | ≤ 1m      | `:dented`      |
| Metal    | > 1m      | `:resistant`   |

**Design Notes:**
- Stateless function (no side effects)
- Replay-safe for match history
- Future: trajectory intersection for mid-flight targets

---

### 5.2 Damage Evaluator (`lib/artillery/engines/damage_evaluator.rb`)

**Purpose:** Translate hit results into game scoring.

**Interface:**
```ruby
score = Artillery::Engines::DamageEvaluator.call(
  result: :destroyed,
  distance: 5.4
)
```

#### Scoring Formula

**Base Points:**
```ruby
case result
when :destroyed then 100
when :damaged   then  50
when :dented    then  25
when :resistant then   0
when :missed    then   0
else                  0  # Unknown result
end
```

**Distance Penalty:**
```ruby
penalty = distance * 2
final_score = [base_points - penalty, 0].max
```

**Example Calculations:**

| Result      | Distance | Base | Penalty | Final |
|-------------|----------|------|---------|-------|
| `:destroyed`| 2.0m     | 100  | 4       | 96    |
| `:damaged`  | 10.0m    | 50   | 20      | 30    |
| `:destroyed`| 60.0m    | 100  | 120     | 0     |

**Design Philosophy:**
- Encourages precision over distant hits
- Prevents negative scores (minimum 0)
- Pure function for deterministic replays

---

## 6. Component & Mechanism System

The mechanism system enables player customization and per-match variance.

### 6.1 Conceptual Model

**Mechanism** - A single customizable component of an artillery piece.

**Examples:**
- `ElevationDial` - Controls angle precision
- `PowderCharges` - Determines muzzle velocity
- `RecoilDampener` - Affects shell weight/trajectory
- `ParachuteTrigger` - Deploys parachute mid-flight

**Properties:**
- **Slot Key** - Which input it controls (`:elevation`, `:powder_charge`, `:deflection`)
- **Upgrade Level** - Player progression (0-5 typical)
- **Modifiers** - JSONB hash of upgrade bonuses (e.g., `{ precision: +2, variance: -5% }`)

---

### 6.2 Database Schema (Planned)

```ruby
# Persistent player-owned mechanisms
create_table :player_mechanisms do |t|
  t.references :player, null: false
  t.string :type, null: false              # STI: ElevationDial, PowderCharges, etc.
  t.string :slot_key, null: false          # :elevation, :powder_charge, etc.
  t.integer :upgrade_level, default: 0
  t.jsonb :modifiers, default: {}          # { precision: 2, variance_reduction: 5 }
  t.timestamps
end

# Player-defined loadouts (e.g., "Siege Mortar", "Precision Tube")
create_table :player_loadouts do |t|
  t.references :player, null: false
  t.string :label, null: false
  t.string :engine_type, default: 'ballistic_3d'
  t.boolean :default, default: false
  t.timestamps
end

# Mechanisms assigned to loadout slots
create_table :player_loadout_slots do |t|
  t.references :player_loadout, null: false
  t.references :player_mechanism, null: false
  t.string :slot_key, null: false          # Must match mechanism.slot_key
  t.timestamps
end

# Match-specific runtime instances (ephemeral, may not persist)
create_table :resolved_mechanism_runtimes do |t|
  t.references :match, null: false
  t.references :player, null: false
  t.references :player_mechanism, null: false
  t.jsonb :randomized_state, null: false   # Frozen per-match variance
  t.timestamps
end
```

---

### 6.3 Runtime Resolution Pattern

**Flow:**

1. **Match Start:**
   - Player selects `PlayerLoadout` (e.g., "My Siege Setup")
   - System instantiates `ResolvedMechanismRuntime` for each mechanism in loadout
   - Randomization applied: base value ± variance based on upgrade level
   - Runtime state frozen for duration of match

2. **Turn Input:**
   - Player submits raw inputs: `{ elevation: 4, powder: 2, deflection: 0 }`

3. **Mechanism Resolution:**
   - `MechanismResolver` routes each input to corresponding runtime
   - Each runtime simulates variance and returns resolved value
   - Example:
     ```ruby
     # Player input: elevation: 4
     # ElevationDial runtime (upgrade 3): ±2° variance, rolled +1.2°
     # Resolved: angle_deg: 35.2  (base 34° + 1.2° variance)
     ```

4. **Aggregation:**
   - Resolver collects all resolved values into flat hash:
     ```ruby
     {
       angle_deg: 35.2,
       initial_velocity: 580,
       shell_weight: 24.8,
       deflection_deg: 0.0
     }
     ```

5. **Engine Simulation:**
   - Resolved attributes passed to `Ballistic3D.simulate()`
   - Physics runs with match-specific randomized values

---

### 6.4 Current Implementation Status

**Implemented:**
- `ParachuteTrigger` sketch in [app/models/mechanisms/parachute_trigger.rb](app/models/mechanisms/parachute_trigger.rb) (incomplete)

**To-Do:**
- ActiveRecord models for `PlayerMechanism`, `PlayerLoadout`, etc.
- `ResolvedMechanismRuntime` class
- `MechanismResolver` aggregation logic
- Specific mechanism subclasses (`ElevationDial`, `PowderCharges`, etc.)

---

## 7. Game Flow

### 7.1 Match Lifecycle (Planned)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. MATCH SETUP                                              │
│    - Players select PlayerLoadout                           │
│    - System creates ResolvedMechanismRuntimes (randomized)  │
│    - Targets spawned on map                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. TURN SUBMISSION                                          │
│    - Player submits input: { elevation: 4, powder: 2, ... } │
│    - Turbo Frame POSTs to /matches/:id/turns                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. MECHANISM RESOLUTION                                     │
│    - MechanismResolver.call(player_input, runtimes)         │
│    - Returns: { angle_deg: 35.2, initial_velocity: 580 }   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. PHYSICS SIMULATION                                       │
│    - Ballistic3D.simulate(resolved_attributes)              │
│    - Returns: { impact_xyz, flight_time, trace }           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. TARGET EVALUATION                                        │
│    - TargetResolution.evaluate(impact_xyz, targets)         │
│    - Returns: [{ target, result, distance }, ...]          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. SCORING                                                  │
│    - DamageEvaluator.call(result, distance) for each hit    │
│    - Update player scores in database                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. UI UPDATE                                                │
│    - Turbo Stream broadcasts match state to all players     │
│    - Stimulus controllers animate trajectory                │
│    - Next player's turn begins                              │
└─────────────────────────────────────────────────────────────┘
```

---

### 7.2 Turbo/Stimulus Integration (Planned)

**Turbo Frames:**
- `<turbo-frame id="match-state">` - Live match scoreboard
- `<turbo-frame id="turn-input">` - Player control panel
- `<turbo-frame id="trajectory-viewer">` - Animated shot path

**Turbo Streams:**
```ruby
# After simulation completes (TurnsController#create)
Turbo::StreamsChannel.broadcast_replace_to(
  "match_#{match.id}",
  target: "match-state",
  partial: "matches/state",
  locals: { match: match }
)

Turbo::StreamsChannel.broadcast_append_to(
  "match_#{match.id}",
  target: "match-log",
  partial: "matches/turn_result",
  locals: { result: turn_result }
)
```

**Stimulus Controllers (Planned):**
- `trajectory-controller.js` - Animates shot path using trace data
- `turn-input-controller.js` - Validates/submits player input
- `match-state-controller.js` - Real-time score updates

---

## 8. Rails Integration

### 8.1 Controllers (To Be Implemented)

**Planned Structure:**

```ruby
# app/controllers/matches_controller.rb
class MatchesController < ApplicationController
  def show
    @match = Match.find(params[:id])
    @player_runtime = @match.player_runtimes.find_by(player: current_player)
  end

  def create
    # Create match, spawn targets, initialize runtimes
  end
end

# app/controllers/turns_controller.rb
class TurnsController < ApplicationController
  def create
    match = Match.find(params[:match_id])
    turn = match.turns.create!(turn_params.merge(player: current_player))

    # Background job for simulation
    TurnSimulationJob.perform_later(turn.id)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(...) }
    end
  end
end
```

---

### 8.2 Views (To Be Implemented)

**Layout ([app/views/layouts/application.html.erb](app/views/layouts/application.html.erb)):**

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-gray-900 text-gray-100">
    <div class="container mx-auto px-4">
      <%= yield %>
    </div>
  </body>
</html>
```

**Match View (Planned):**

```erb
<!-- app/views/matches/show.html.erb -->
<%= turbo_stream_from "match_#{@match.id}" %>

<div class="grid grid-cols-2 gap-8">
  <!-- Left: Match State -->
  <%= turbo_frame_tag "match-state" do %>
    <%= render "match_state", match: @match %>
  <% end %>

  <!-- Right: Turn Input -->
  <%= turbo_frame_tag "turn-input" do %>
    <%= render "turn_input", match: @match, runtime: @player_runtime %>
  <% end %>
</div>

<!-- Trajectory Viewer -->
<div class="mt-8" data-controller="trajectory">
  <canvas id="trajectory-canvas" width="800" height="600"></canvas>
</div>
```

---

### 8.3 JavaScript/Stimulus

**Application Entry ([app/javascript/application.js](app/javascript/application.js)):**

```javascript
import "@hotwired/turbo-rails"
import "controllers"
```

**Stimulus Setup ([app/javascript/controllers/application.js](app/javascript/controllers/application.js)):**

```javascript
import { Application } from "@hotwired/stimulus"

const application = Application.start()
application.debug = false
window.Stimulus = application

export { application }
```

**Example Controller (Planned):**

```javascript
// app/javascript/controllers/trajectory_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    trace: Array  // Array of { position: [x,y,z], time: t } from simulation
  }

  connect() {
    this.canvas = this.element.querySelector("canvas")
    this.ctx = this.canvas.getContext("2d")
    this.animateTrajectory()
  }

  animateTrajectory() {
    const trace = this.traceValue
    let index = 0

    const animate = () => {
      if (index >= trace.length) return

      const point = trace[index]
      this.drawPoint(point.position)
      index++

      requestAnimationFrame(animate)
    }

    animate()
  }

  drawPoint(position) {
    // Project 3D position to 2D canvas
    const x = position[0] * 2 + 400  // Scale + offset
    const y = 600 - (position[2] * 2) // Flip Y axis

    this.ctx.fillStyle = "#ff6b6b"
    this.ctx.fillRect(x - 2, y - 2, 4, 4)
  }
}
```

---

### 8.4 Importmap Configuration

**[config/importmap.rb](config/importmap.rb):**

```ruby
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
```

**Benefits:**
- No npm/webpack required
- Native ES module imports
- HTTP/2 multiplexing for performance

---

### 8.5 Autoloading Configuration

**[config/initializers/zeitwerk_lib.rb](config/initializers/zeitwerk_lib.rb):**

```ruby
# Autoload lib/artillery/* using Zeitwerk
Rails.autoloaders.main.push_dir(
  Rails.root.join("lib"),
  namespace: Object
)
```

**Effect:**
- `lib/artillery/engines/ballistic_3d.rb` → `Artillery::Engines::Ballistic3D`
- No need for manual `require` statements
- Consistent with Rails 8 conventions

---

## 9. Domain Model

### 9.1 Entity-Relationship Diagram (Planned)

```
┌──────────────┐
│   Player     │
└──────┬───────┘
       │ 1:N
       │
┌──────▼───────────────┐
│ PlayerMechanism      │
│  - type (STI)        │
│  - slot_key          │
│  - upgrade_level     │
│  - modifiers (JSONB) │
└──────┬───────────────┘
       │ N:M
       │
┌──────▼───────────────┐
│ PlayerLoadout        │
│  - label             │
│  - engine_type       │
│  - default           │
└──────┬───────────────┘
       │ 1:N
       │
┌──────▼───────────────────┐
│ PlayerLoadoutSlot        │
│  - slot_key              │
│  - player_mechanism_id   │
└──────────────────────────┘

┌──────────────┐
│   Match      │
└──────┬───────┘
       │ 1:N
       │
┌──────▼─────────────────────┐
│ ResolvedMechanismRuntime   │
│  - player_id               │
│  - player_mechanism_id     │
│  - randomized_state (JSONB)│
└────────────────────────────┘

┌──────────────┐
│   Match      │
└──────┬───────┘
       │ 1:N
       │
┌──────▼───────────────┐
│   Turn               │
│  - player_id         │
│  - input (JSONB)     │
│  - result (JSONB)    │
│  - score             │
└──────────────────────┘

┌──────────────┐
│   Match      │
└──────┬───────┘
       │ 1:N
       │
┌──────▼───────────────┐
│   Target             │
│  - position (JSONB)  │
│  - material          │
│  - destroyed         │
└──────────────────────┘
```

---

### 9.2 Key Models (To Be Implemented)

**Player:**
```ruby
class Player < ApplicationRecord
  has_many :player_mechanisms
  has_many :player_loadouts
end
```

**PlayerMechanism (STI):**
```ruby
class PlayerMechanism < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots
  has_many :player_loadouts, through: :player_loadout_slots

  # STI subclasses: ElevationDial, PowderCharges, RecoilDampener, etc.
end
```

**PlayerLoadout:**
```ruby
class PlayerLoadout < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots
  has_many :player_mechanisms, through: :player_loadout_slots
end
```

**Match:**
```ruby
class Match < ApplicationRecord
  has_many :players, through: :match_players
  has_many :turns
  has_many :targets
  has_many :resolved_mechanism_runtimes
end
```

**Turn:**
```ruby
class Turn < ApplicationRecord
  belongs_to :match
  belongs_to :player

  # Store raw input + resolved attributes + simulation results
  store :input, coder: JSON       # { elevation: 4, powder: 2 }
  store :resolved, coder: JSON    # { angle_deg: 35.2, ... }
  store :result, coder: JSON      # { impact_xyz, flight_time, trace }
end
```

---

## 10. Design Patterns

### 10.1 Template Method Pattern

**Usage:** Abstract base classes defining algorithm structure

**Example:**
```ruby
# lib/artillery/engines/affectors/base.rb
class Base
  def call!(state, dt)
    raise NotImplementedError
  end
end

# Subclasses implement call! with specific physics
class Gravity < Base
  def call!(state, dt)
    state.acceleration.z -= @gravity
  end
end
```

---

### 10.2 Strategy Pattern

**Usage:** Pluggable affectors/hooks

**Example:**
```ruby
# Client code configures engine with different strategies
engine = Ballistic3D.new(
  affectors: [
    Gravity.new(gravity: 9.81),      # Earth gravity
    AirResistance.new(air_density: 1.225)
  ]
)

# vs.

engine = Ballistic3D.new(
  affectors: [
    Gravity.new(gravity: 1.62),      # Lunar gravity
    # No air resistance (vacuum)
  ]
)
```

---

### 10.3 Composition Over Inheritance

**Usage:** Engine composes affectors/hooks arrays

**Benefits:**
- Add/remove behaviors at runtime
- No deep inheritance hierarchies
- Testable in isolation

**Example:**
```ruby
class Ballistic3D
  def initialize(affectors:, before_hooks: [], after_hooks: [])
    @affectors = affectors
    @before_hooks = before_hooks
    @after_hooks = after_hooks
  end

  def simulate(inputs)
    state = build_initial_state(inputs)

    until state.position.z <= 0
      @before_hooks.each { |hook| hook.tick(state, TICK) }
      @affectors.each { |affector| affector.call!(state, TICK) }
      integrate_physics!(state, TICK)
      @after_hooks.each { |hook| hook.tick(state, TICK) }
    end

    # ...
  end
end
```

---

### 10.4 Value Object Pattern

**Usage:** Immutable data structures

**Examples:**
- `Vector` - 3D coordinates
- `ShotState` - Ballistic state snapshot
- `Inputs` - Engine parameters

**Benefits:**
- Safe to pass between functions
- Deep copy via `dup` for history tracking
- Functional programming style

---

### 10.5 Factory Method Pattern

**Usage:** Input validation and construction

**Example:**
```ruby
class Ballistic3D
  class Inputs
    def self.from_resolver(angle_deg:, initial_velocity:, shell_weight:, **opts)
      raise ArgumentError, "angle_deg required" unless angle_deg
      raise ArgumentError, "initial_velocity required" unless initial_velocity
      raise ArgumentError, "shell_weight required" unless shell_weight

      new(
        angle_deg: angle_deg.to_f,
        initial_velocity: initial_velocity.to_f,
        shell_weight: shell_weight.to_f,
        deflection_deg: opts[:deflection_deg]&.to_f || 0.0,
        area_of_effect: opts[:area_of_effect]&.to_f || 0.0
      )
    end
  end
end
```

---

### 10.6 Stateless Service Pattern

**Usage:** Engines with no mutable state

**Examples:**
- `TargetResolution.evaluate()` - Pure function
- `DamageEvaluator.call()` - Deterministic scoring

**Benefits:**
- Thread-safe
- Replay-safe for match history
- Easy to test (no setup/teardown)

---

## 11. Testing Strategy

### 11.1 Current Test Coverage

**RSpec Configuration ([spec/spec_helper.rb](spec/spec_helper.rb)):**

```ruby
require 'factory_bot'
FactoryBot.find_definitions

# Zeitwerk autoloading for lib/
loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('../lib', __dir__))
loader.setup

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
```

---

### 11.2 Affector Unit Tests

**Gravity ([spec/lib/artillery/engines/affectors/gravity_spec.rb](spec/lib/artillery/engines/affectors/gravity_spec.rb)):**

```ruby
RSpec.describe Artillery::Engines::Affectors::Gravity do
  it "applies default Earth gravity (-9.81 m/s²)" do
    affector = described_class.new
    state = Artillery::Physics::ShotState.new(...)

    affector.call!(state, 0.05)

    expect(state.acceleration.z).to eq(-9.81)
  end

  it "applies custom gravity (lunar: -1.62 m/s²)" do
    affector = described_class.new(gravity: 1.62)
    state = Artillery::Physics::ShotState.new(...)

    affector.call!(state, 0.05)

    expect(state.acceleration.z).to eq(-1.62)
  end
end
```

**Air Resistance ([spec/lib/artillery/engines/affectors/air_resistance_spec.rb](spec/lib/artillery/engines/affectors/air_resistance_spec.rb)):**

```ruby
RSpec.describe Artillery::Engines::Affectors::AirResistance do
  it "applies no drag when velocity is zero" do
    affector = described_class.new
    state = Artillery::Physics::ShotState.new(
      velocity: Artillery::Physics::Vector.new(0, 0, 0),
      ...
    )
    initial_accel = state.acceleration.dup

    affector.call!(state, 0.05)

    expect(state.acceleration).to eq(initial_accel)
  end

  it "applies quadratic drag opposing velocity" do
    affector = described_class.new(air_density: 1.225, drag_coefficient: 0.47)
    state = Artillery::Physics::ShotState.new(
      velocity: Artillery::Physics::Vector.new(100, 0, 0),
      mass: 25,
      surface_area: 0.05,
      ...
    )

    affector.call!(state, 0.05)

    # F_drag = 0.5 * 1.225 * 100² * 0.47 * 0.05 = 144.09 N
    # a_drag = 144.09 / 25 = 5.76 m/s²
    # Direction: -X (opposes velocity)
    expect(state.acceleration.x).to be_within(0.01).of(-5.76)
  end
end
```

**Wind ([spec/lib/artillery/engines/affectors/wind_spec.rb](spec/lib/artillery/engines/affectors/wind_spec.rb)):**

```ruby
RSpec.describe Artillery::Engines::Affectors::Wind do
  it "scales wind by surface area" do
    wind_vector = Artillery::Physics::Vector.new(0.5, 0, 0)  # 0.5 m/s² per m²
    affector = described_class.new(wind_vector: wind_vector)
    state = Artillery::Physics::ShotState.new(
      surface_area: 2.0,  # 2 m²
      ...
    )

    affector.call!(state, 0.05)

    # Expected: 0.5 * 2.0 = 1.0 m/s² in +X direction
    expect(state.acceleration.x).to eq(1.0)
  end
end
```

**Test Results:**
```
$ rspec spec/lib/artillery/engines/affectors/

Finished in 0.012 seconds (files took 0.5 seconds to load)
5 examples, 0 failures
```

---

### 11.3 Test Gaps (To Be Filled)

1. **Integration Tests:**
   - Multiple affectors + hooks working together
   - Full `Ballistic3D.simulate()` end-to-end test

2. **Target Resolution:**
   - Edge cases (impact exactly at threshold distance)
   - Multiple targets with mixed materials

3. **Damage Evaluator:**
   - Distance penalty edge cases
   - Negative score prevention

4. **Mechanism System:**
   - `MechanismResolver` aggregation logic
   - Randomization boundaries
   - Upgrade modifier application

---

## 12. Key Architectural Decisions

### 12.1 Physics Engine Design

**Decision:** Fixed-timestep Euler integration

**Rationale:**
- Deterministic: Same inputs always produce same outputs
- Simple: Easy to understand and debug
- Sufficient accuracy for arcade-style game (not aerospace simulation)

**Trade-offs:**
- Lower accuracy than Runge-Kutta or Verlet integration
- Requires small timestep (0.05s) for stability
- Cannot dynamically adjust timestep for performance

---

### 12.2 Modular Affectors

**Decision:** Composition-based force application

**Rationale:**
- Extensibility: Add new forces without modifying engine core
- Testability: Each affector unit-tested in isolation
- Flexibility: Different game modes can enable/disable forces

**Trade-offs:**
- Slight performance overhead (array iteration)
- Affector order can matter (though rare)

---

### 12.3 Per-Match Mechanism Randomization

**Decision:** Freeze variance at match start (not per-turn)

**Rationale:**
- Fairness: Players adapt to consistent equipment across match
- Simplicity: No need to store randomness seeds per turn
- Replayability: Match can be replayed with same variances

**Trade-offs:**
- Less variance than per-turn randomization
- More predictable after early turns

---

### 12.4 Server-Side Simulation

**Decision:** All physics runs on server, not client

**Rationale:**
- Anti-cheat: Client cannot manipulate physics
- Consistency: All players see identical results
- Authority: Server is source of truth

**Trade-offs:**
- Latency: Must wait for server response
- Load: Server CPU must handle all simulations
- Mitigation: Background jobs (Solid Queue) for parallelism

---

### 12.5 Stateless Engines

**Decision:** `TargetResolution` and `DamageEvaluator` are pure functions

**Rationale:**
- Replay-safe: Can re-evaluate past turns without side effects
- Testability: No mocking required
- Parallelism: Thread-safe for concurrent evaluations

**Trade-offs:**
- Cannot store intermediate state for debugging
- Must pass all data as parameters

---

### 12.6 Zeitwerk Autoloading for lib/

**Decision:** Use Rails 8 Zeitwerk to autoload `lib/artillery/*`

**Rationale:**
- Consistency: Same autoloading as `app/`
- Convenience: No manual `require` statements
- Modern Rails: Aligns with Rails 8 conventions

**Trade-offs:**
- Strict naming conventions (file/class name must match)
- Harder to extract lib/ to gem later (minor concern)

---

### 12.7 Hotwire/Turbo for UI

**Decision:** Use Turbo Frames/Streams instead of full React/Vue SPA

**Rationale:**
- Simplicity: Server-rendered HTML with progressive enhancement
- Performance: Minimal JavaScript bundle size
- Rails Integration: Native support in Rails 8
- Real-time: Turbo Streams over WebSockets for live updates

**Trade-offs:**
- Less rich interactions than full SPA
- Animations require custom Stimulus controllers
- Learning curve for developers unfamiliar with Hotwire

---

## 13. Development Roadmap

### Phase 1: Core Mechanics (Current)

**Status:** ~60% Complete

- [x] Physics engine (Ballistic3D)
- [x] Affectors (Gravity, AirResistance, Wind)
- [x] Flight hooks (Parachute)
- [x] Target resolution
- [x] Damage evaluation
- [x] Unit tests for affectors
- [ ] Integration tests for full simulation
- [ ] Database models (PlayerMechanism, Match, Turn)
- [ ] MechanismResolver implementation

---

### Phase 2: Game Flow

**Status:** Not Started

- [ ] Match controller (create, show)
- [ ] Turn controller (create, evaluate)
- [ ] Target spawning logic
- [ ] Scoring/leaderboard
- [ ] Match history/replay
- [ ] Background jobs for simulation (Solid Queue)

---

### Phase 3: UI/UX

**Status:** Not Started

- [ ] Match view layout
- [ ] Turn input form (Stimulus controller)
- [ ] Trajectory animation (canvas-based)
- [ ] Real-time score updates (Turbo Streams)
- [ ] Match lobby/matchmaking
- [ ] Mobile-responsive design (Tailwind)

---

### Phase 4: Progression System

**Status:** Not Started

- [ ] PlayerMechanism upgrade system
- [ ] Currency/rewards
- [ ] Loadout builder UI
- [ ] Mechanism shop
- [ ] Tutorial/onboarding

---

### Phase 5: Advanced Features

**Status:** Not Started

- [ ] Alternate engine types (non-ballistic)
- [ ] Additional affectors (Magnus effect, spin, Coriolis)
- [ ] Proximity fuses (flight hooks)
- [ ] Multiplayer matchmaking
- [ ] Replay system
- [ ] Analytics dashboard

---

## Conclusion

Artillery is a **well-architected early-stage game project** with a solid foundation:

**Strengths:**
1. **Modular physics engine** - Pluggable affectors/hooks for extensibility
2. **Deterministic simulation** - Replay-safe, server-authoritative
3. **Clear separation of concerns** - Physics in `lib/`, persistence in `app/`
4. **Test-driven development** - Unit tests for critical physics components
5. **Modern Rails stack** - Hotwire/Turbo for real-time interactions
6. **Thoughtful design** - Value objects, stateless services, composition patterns

**Next Critical Steps:**
1. Implement `PlayerMechanism` and `MechanismResolver` to connect mechanisms to physics
2. Create Match/Turn controllers and views for playable prototype
3. Build Stimulus-based trajectory animation for visual feedback
4. Add integration tests for full simulation pipeline

The project is **well-positioned for rapid development** once the mechanism system and UI layer are completed. The physics engine is production-ready, and the architectural patterns will scale cleanly as features are added.

---

**Document Version:** 1.0
**Author:** Claude (Anthropic)
**Date:** 2025-11-15