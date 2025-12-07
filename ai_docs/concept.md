# ⚙️ Artillery Game Architecture & Mechanism Customization Design

_Last updated: [DATE]_

## 🎯 Goal

Design a modular, extensible architecture for a web-based multiplayer artillery game where:

- Players compete using customizable artillery systems.
- Each artillery piece consists of randomized mechanisms (e.g., dials, gauges).
- Players own and upgrade mechanisms over time to influence gameplay behavior.
- Turn-based rounds are resolved consistently server-side via deterministic simulation engines.
- Platform design is highly composable, modular, and supports sustained growth.

---

## 🧱 Architectural Overview

### Key Layers:

| Layer             | Purpose                                             | Lifetime        |
|------------------|-----------------------------------------------------|-----------------|
| `PlayerMechanism`| Persistent, player-owned component configuration    | Long-term       |
| `PlayerLoadout`  | Named set of mechanisms the player builds/edits     | Long-term       |
| `ArtilleryEngine`| Stateless simulator that consumes resolved inputs   | Fixed, reusable |
| `Match`          | A multiplayer engagement between players            | Ephemeral       |
| `ResolvedMechanismRuntime` | In-memory instance used during simulation | Per-match       |

Mechanisms encapsulate all interactive, upgradeable, and randomized behavior. Engines remain clean and stateless: they receive resolved values and know nothing of mechanisms.

---

## 🧩 Core Concepts

### 🔧 Mechanism

- The fundamental unit of control.
- Represented as a Ruby class — upgraded by the player and instantiated per match with randomized internal logic.
- Examples: `ElevationDial`, `PowderCharges`, `RecoilDampener`

All mechanisms must implement:

```ruby
class Mechanism
  def slot_key              # e.g. :elevation
  def input_keys            # e.g. [:elevation]
  def simulate(input_hash)  # returns {angle_deg: <value>, etc}
end

---

🧪 PlayerMechanism (DB Model)
The persistent customizable mechanism the player owns.

create_table :player_mechanisms do |t|
  t.references :player
  t.string :type           # STI, e.g., ElevationDial
  t.string :slot_key       # Input role, e.g., :elevation
  t.integer :upgrade_level
  t.jsonb :modifiers       # e.g., { "precision_bonus": 0.2 }
  t.timestamps
end

Each subclass defines how upgrades impact behavior.

---

create_table :player_loadouts do |t|
  t.references :player
  t.string :label         # "Siege Mortar", "Precision Tube"
  t.string :engine_type
  t.boolean :default, default: false
  t.timestamps
end

create_table :player_loadout_slots do |t|
  t.references :player_loadout
  t.references :player_mechanism
  t.string :slot_key      # MUST align with PlayerMechanism.slot_key
  t.timestamps
end

---

🏁 Match Lifecycle
At match start:

Player selects a PlayerLoadout.
Each PlayerMechanism in the loadout is transformed into a ResolvedMechanismRuntime (randomized, frozen).
An engine resolves the turn using values emitted by those mechanisms.
No other per-match duplication of business logic is required.

🧬 Runtime Mechanism Pattern

class ElevationDialRuntime
  def initialize(mode:, tuning_bonus:, upgrade_level:)
    # randomized + upgrade-aware instance
  end

  def simulate(input:)
    degrees = case @mode
              when :small_tick then input * 0.5
              when :large_tick then input * 3.0
              end
    { angle_deg: degrees * (1 + @tuning_bonus) }
  end
end

Each PlayerMechanism #to_runtime_instance generates one of these per match.

---

🧠 Engine Interface
All engines receive resolved simulation values (angles, velocity, shell weight, etc). They do not directly deal with Mechanism classes.

class Ballistic3DEngine
  def simulate(attrs)
    # Receives e.g. { angle_deg: 35.0, initial_velocity: 600, shell_weight: 25 }
    # Returns trajectory + impact result
  end
end

---

🧰 Mechanism Resolver

class MechanismResolver
  def initialize(resolved_mechanisms, input_values)
    @resolved_mechanisms = resolved_mechanisms
    @inputs = input_values
  end

  def resolved_attributes
    @resolved_mechanisms.flat_map do |mech|
      mech.simulate(@inputs.slice(*mech.input_keys))
    end.reduce({}) { |acc, h| h.each { |k, v| acc[k] ||= 0; acc[k] += v }; acc }
  end
end

---

🎮 Turn Flow
Player submits input (e.g., elevation: 4, powder: 2)
Input is routed to each active MechanismRuntime
Mechanism simulation values are aggregated
Engine receives resolved attributes and computes output
Result is sent back to clients via Turbo/Stimulus


---

🪄 DSL Sketch (TBD)
Future feature: a YAML DSL for defining artillery platforms that seed into player loadouts. Example:

name: whisper_mortar
engine: ballistic_3d
mechanisms:
  - type: elevation_dial
    slot: elevation
    mode: random
  - type: powder_charges
    from: 200
    to: 600
    per_charge: 50

Will require code generation or dynamic slot building logic.

---

✅ Summary of Design Benefits
🔁 Fully composable mechanism logic: per mechanism, not per artillery system
🧠 All intelligence resides in Mechanism, engines remain generic
📂 Normalized DB schema supports upgrades, progression, and replay determinism
💾 Players build, store, and swap named loadouts
🧪 Runtime resolution of player-owned mechanisms creates fair and replayable matches
🧩 Extensible: new engines, mechanisms, or upgrade types can be added modularly
📎 Coming Later
Mechanism fusion / dual-stack systems ?
Crafting & progressive enhancement systems ?
Loadout validation and min/max rules
Match replay storage or simulation seeding for analytics
Visual dial/simulator builder tool
