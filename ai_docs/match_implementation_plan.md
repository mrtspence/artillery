# Match System Implementation Plan

**Date:** 2025-12-08
**Context:** Implementing asynchronous multiplayer match hosting system
**Status:** Approved - Approach A (Stateful Match Aggregate)
**Play Style:** Asynchronous turn-based (play-by-mail style) with optional synchronous play

---

## Executive Summary

This document presents **three distinct architectural approaches** for implementing the match hosting system for Artillery. Each approach offers different trade-offs in complexity, flexibility, and real-time capabilities.

### Key Requirements (MVP)

1. **Remove email from Player** - Username-only identification (User model for auth will be added later with Devise)
2. **Match Model** - Support 2-8 players in a single game instance
3. **Asynchronous Play** - Players can take turns whenever they're available (play-by-mail style)
4. **Lobby System** - Match codes/invites for players to join
5. **Map/Terrain System** - Store battlefield layout, artillery positions, targets
6. **Turn System** - Track player inputs, ballistic simulation results, trajectory data
7. **UI** - Active player controls, non-active player waiting view, map visualization, trajectory playback
8. **Notifications** - Players notified when it's their turn (basic - can be enhanced later)

### Deferred Features (Future Enhancements)

- Turn timers / time limits
- Simultaneous turn planning
- In-match chat
- Spectator mode
- Matchmaking system
- Ranked play / ELO
- Match replays / archives
- Advanced analytics

### Selected Approach

**Approach A: Stateful Match Aggregate** - Simple, monolithic match state with JSONB. This approach is optimal for asynchronous play-by-mail style gameplay.

*(Alternative approaches B and C are documented below for reference but not recommended for MVP)*

---

##  Approach A: Stateful Match Aggregate

### Philosophy

"Keep it simple" - Single Match model as the source of truth, with state stored in JSONB columns. Focus on getting a working multiplayer game quickly.

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        Match (Core Aggregate)                │
│  - state: enum (setup, in_progress, completed)              │
│  - lobby_code: string (6-char code for joining, e.g. ABC123)│
│  - current_player_id: FK to players table                    │
│  - match_config: JSONB (settings, rules)                     │
│  - created_at, updated_at                                    │
└──────────────────────────────────────────────────────────────┘
                          │
                          ├─── has_many :match_players
                          ├─── has_many :players, through: :match_players
                          ├─── has_one :map
                          └─── has_many :turns (ordered)

┌──────────────────────────────────────────────────────────────┐
│                      MatchPlayer (Join Table)                │
│  - match_id: FK                                              │
│  - player_id: FK                                             │
│  - player_loadout_id: FK                                     │
│  - position_on_map: JSONB { x: 0, y: 0, z: 0 }             │
│  - turn_order: integer                                       │
│  - score: integer                                            │
│  - status: enum (active, spectating, eliminated)             │
│  - runtimes_state: JSONB (frozen mechanism runtimes)         │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                          Map                                 │
│  - match_id: FK (unique)                                     │
│  - name: string                                              │
│  - terrain_data: JSONB (elevation grid, obstacles)           │
│  - boundaries: JSONB { min_x, max_x, min_y, max_y }         │
│  - environment: JSONB (wind, weather)                        │
└──────────────────────────────────────────────────────────────┘
                          │
                          └─── has_many :map_targets

┌──────────────────────────────────────────────────────────────┐
│                        MapTarget                             │
│  - map_id: FK                                                │
│  - position: JSONB { x, y, z }                              │
│  - target_type: string (stationary, moving, etc)             │
│  - material: enum (paper, wood, metal)                       │
│  - health: integer (for multi-hit targets)                   │
│  - destroyed: boolean                                        │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                           Turn                               │
│  - match_id: FK                                              │
│  - match_player_id: FK (who took this turn)                  │
│  - turn_number: integer                                      │
│  - player_input: JSONB { elevation: 4, powder: 2, ... }     │
│  - resolved_attributes: JSONB (from pipeline)                │
│  - ballistic_result: JSONB (impact_xyz, flight_time, trace) │
│  - targets_hit: JSONB [{ target_id, result, damage }]       │
│  - score_delta: integer                                      │
│  - created_at: timestamp                                     │
└──────────────────────────────────────────────────────────────┘
```

### Database Schema

```ruby
# Migration: Remove email from players
class RemoveEmailFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_index :players, :email
    remove_column :players, :email, :string
  end
end

# Migration: Create matches
class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.string :state, null: false, default: 'setup'
      t.string :lobby_code, null: false  # 6-character code for joining (e.g., "ABC123")
      t.references :current_player, foreign_key: { to_table: :players }
      t.jsonb :match_config, default: {}, null: false
      t.integer :turn_limit, default: 10
      t.integer :current_turn_number, default: 0
      t.timestamps
    end

    add_index :matches, :state
    add_index :matches, :lobby_code, unique: true
  end
end

# Migration: Create match_players
class CreateMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :match_players do |t|
      t.references :match, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :player_loadout, null: false, foreign_key: true
      t.jsonb :position_on_map, null: false
      t.integer :turn_order, null: false
      t.integer :score, default: 0, null: false
      t.string :status, default: 'active', null: false
      t.jsonb :runtimes_state, default: {}, null: false
      t.timestamps
    end

    add_index :match_players, [:match_id, :turn_order], unique: true
    add_index :match_players, [:match_id, :player_id], unique: true
  end
end

# Migration: Create maps
class CreateMaps < ActiveRecord::Migration[8.1]
  def change
    create_table :maps do |t|
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.jsonb :terrain_data, default: {}, null: false
      t.jsonb :boundaries, null: false
      t.jsonb :environment, default: {}, null: false
      t.timestamps
    end
  end
end

# Migration: Create map_targets
class CreateMapTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :map_targets do |t|
      t.references :map, null: false, foreign_key: true
      t.jsonb :position, null: false
      t.string :target_type, null: false
      t.string :material, null: false
      t.integer :health, default: 100, null: false
      t.boolean :destroyed, default: false, null: false
      t.timestamps
    end

    add_index :map_targets, [:map_id, :destroyed]
  end
end

# Migration: Create turns
class CreateTurns < ActiveRecord::Migration[8.1]
  def change
    create_table :turns do |t|
      t.references :match, null: false, foreign_key: true
      t.references :match_player, null: false, foreign_key: true
      t.integer :turn_number, null: false
      t.jsonb :player_input, null: false
      t.jsonb :resolved_attributes, default: {}, null: false
      t.jsonb :ballistic_result, default: {}, null: false
      t.jsonb :targets_hit, default: [], null: false
      t.integer :score_delta, default: 0, null: false
      t.timestamp :created_at, null: false
    end

    add_index :turns, [:match_id, :turn_number], unique: true
    add_index :turns, :created_at
  end
end
```

### Model Implementations

```ruby
# app/models/player.rb
class Player < ApplicationRecord
  has_many :player_mechanisms, dependent: :destroy
  has_many :player_loadouts, dependent: :destroy
  has_many :match_players, dependent: :destroy
  has_many :matches, through: :match_players

  validates :username, presence: true, uniqueness: true
  # email validation removed
end

# app/models/match.rb
class Match < ApplicationRecord
  # State machine
  enum state: {
    setup: 'setup',          # Players joining, configuring
    in_progress: 'in_progress',  # Active gameplay
    completed: 'completed',   # Match finished
    abandoned: 'abandoned'    # Match cancelled
  }

  # Associations
  belongs_to :current_player, class_name: 'Player', optional: true
  has_many :match_players, dependent: :destroy
  has_many :players, through: :match_players
  has_one :map, dependent: :destroy
  has_many :turns, dependent: :destroy

  # Validations
  validates :state, presence: true
  validates :lobby_code, presence: true, uniqueness: true, length: { is: 6 }
  validate :minimum_players, if: :in_progress?
  validate :maximum_players

  # Callbacks
  before_validation :generate_lobby_code, on: :create
  after_create :create_map
  after_create :set_turn_order

  # State transitions
  def start!
    return false unless can_start?

    transaction do
      # Instantiate runtimes for all players
      match_players.each(&:instantiate_runtimes!)

      # Set first player as current
      update!(
        state: :in_progress,
        current_player: match_players.order(:turn_order).first.player,
        current_turn_number: 1
      )

      # Broadcast match started
      broadcast_match_state_update
    end
  end

  def advance_turn!
    return false unless in_progress?

    transaction do
      next_player = find_next_player
      increment!(:current_turn_number)

      if current_turn_number > turn_limit
        complete!
      else
        update!(current_player: next_player)
        broadcast_turn_changed
      end
    end
  end

  def complete!
    update!(state: :completed, current_player: nil)
    broadcast_match_completed
  end

  # Query methods
  def active_match_player
    match_players.find_by(player: current_player)
  end

  def other_match_players
    match_players.where.not(player: current_player)
  end

  def winning_player
    match_players.order(score: :desc).first&.player
  end

  def can_start?
    setup? && match_players.count >= 2 && match_players.all?(&:loadout_valid?)
  end

  private

  def minimum_players
    errors.add(:base, "Match must have at least 2 players") if players.count < 2
  end

  def maximum_players
    errors.add(:base, "Match cannot have more than 8 players") if players.count > 8
  end

  def find_next_player
    current_turn = match_players.find_by(player: current_player).turn_order
    next_turn = (current_turn % match_players.count) + 1
    match_players.find_by(turn_order: next_turn).player
  end

  def set_turn_order
    match_players.order(:created_at).each_with_index do |mp, index|
      mp.update!(turn_order: index + 1)
    end
  end

  def generate_lobby_code
    return if lobby_code.present?

    # Generate unique 6-character code (e.g., "ABC123")
    loop do
      code = SecureRandom.alphanumeric(6).upcase
      self.lobby_code = code
      break unless Match.exists?(lobby_code: code)
    end
  end

  def broadcast_match_state_update
    broadcast_replace_to(
      "match_#{id}",
      target: "match_state",
      partial: "matches/state",
      locals: { match: self }
    )
  end

  def broadcast_turn_changed
    broadcast_replace_to(
      "match_#{id}",
      target: "current_turn",
      partial: "matches/turn_indicator",
      locals: { match: self }
    )
  end

  def broadcast_match_completed
    broadcast_replace_to(
      "match_#{id}",
      target: "match_container",
      partial: "matches/completed",
      locals: { match: self }
    )
  end
end

# app/models/match_player.rb
class MatchPlayer < ApplicationRecord
  belongs_to :match
  belongs_to :player
  belongs_to :player_loadout
  has_many :turns, dependent: :destroy

  enum status: {
    active: 'active',
    spectating: 'spectating',
    eliminated: 'eliminated'
  }

  validates :turn_order, uniqueness: { scope: :match_id }
  validates :position_on_map, presence: true

  # Instantiate and freeze runtimes for this match
  def instantiate_runtimes!
    return if runtimes_state.present?

    seed = match.id * 1000 + player.id
    runtimes = player_loadout.instantiate_runtimes(match: match, random_seed: seed)

    # Serialize runtime state to JSONB
    serialized = runtimes.map do |runtime|
      {
        class: runtime.class.name,
        mechanism_id: runtime.mechanism.id,
        randomized_state: runtime.instance_variables.each_with_object({}) do |var, hash|
          hash[var.to_s] = runtime.instance_variable_get(var) unless var == :@mechanism
        end
      }
    end

    update!(runtimes_state: serialized)
  end

  # Reconstitute runtimes from frozen state
  def runtimes
    @runtimes ||= runtimes_state.map do |runtime_data|
      klass = runtime_data['class'].constantize
      mechanism = player.player_mechanisms.find(runtime_data['mechanism_id'])

      runtime = klass.new(mechanism: mechanism, match: match, random_seed: 0)

      # Restore randomized state
      runtime_data['randomized_state'].each do |var_name, value|
        runtime.instance_variable_set(var_name, value)
      end

      runtime
    end
  end

  def loadout_valid?
    player_loadout.valid_for_match?
  end

  def is_active_player?
    match.current_player == player
  end
end

# app/models/map.rb
class Map < ApplicationRecord
  belongs_to :match
  has_many :map_targets, dependent: :destroy

  validates :name, presence: true
  validates :boundaries, presence: true
  validates :terrain_data, presence: true

  # Generate default map
  after_create :generate_default_terrain
  after_create :spawn_default_targets

  def width
    boundaries['max_x'] - boundaries['min_x']
  end

  def height
    boundaries['max_y'] - boundaries['min_y']
  end

  def terrain_at(x, y)
    # Simple grid lookup - terrain_data is 2D array
    grid = terrain_data['elevation_grid']
    return 0 unless grid

    x_idx = ((x - boundaries['min_x']) / 10).to_i  # 10m grid cells
    y_idx = ((y - boundaries['min_y']) / 10).to_i
    grid[y_idx]&.[](x_idx) || 0
  end

  private

  def generate_default_terrain
    update!(
      name: "Field #{match.id}",
      boundaries: { 'min_x' => -500, 'max_x' => 500, 'min_y' => -500, 'max_y' => 500 },
      terrain_data: {
        'elevation_grid' => Array.new(100) { Array.new(100, 0) }  # Flat terrain
      },
      environment: {
        'wind_vector' => [0, 0, 0],
        'air_density' => 1.225
      }
    )
  end

  def spawn_default_targets
    # Spawn 5 random targets
    5.times do |i|
      map_targets.create!(
        position: {
          'x' => rand(100..400),
          'y' => rand(-200..200),
          'z' => 0
        },
        target_type: 'stationary',
        material: ['paper', 'wood'].sample,
        health: 100
      )
    end
  end
end

# app/models/map_target.rb
class MapTarget < ApplicationRecord
  belongs_to :map

  enum material: {
    paper: 'paper',
    wood: 'wood',
    metal: 'metal'
  }

  validates :position, presence: true
  validates :target_type, presence: true

  def take_damage!(amount)
    new_health = [health - amount, 0].max
    update!(health: new_health, destroyed: new_health.zero?)
  end

  def coordinates
    [position['x'], position['y'], position['z']]
  end
end

# app/models/turn.rb
class Turn < ApplicationRecord
  belongs_to :match
  belongs_to :match_player

  validates :turn_number, uniqueness: { scope: :match_id }
  validates :player_input, presence: true

  after_create :execute_turn_simulation
  after_create :broadcast_turn_result

  def player
    match_player.player
  end

  private

  def execute_turn_simulation
    # Resolve player inputs through mechanism pipeline
    resolver = Artillery::Mechanisms::PipelineResolver.new(
      match_player.runtimes,
      player_input.symbolize_keys
    )

    resolved = resolver.ballistic_attributes

    # Run ballistic simulation
    engine = Artillery::Engines::Ballistic3D.new(
      before_tick_hooks: resolver.engine_hooks,
      affectors: resolver.engine_affectors.map { |a| ->(state, tick) { a.call(state, tick) } }
    )

    result = engine.simulate(resolved)

    # Evaluate targets
    targets_hit = evaluate_targets(result[:impact_xyz])
    score = targets_hit.sum { |hit| hit[:score] }

    # Update turn record
    update!(
      resolved_attributes: resolved.to_h,
      ballistic_result: result,
      targets_hit: targets_hit,
      score_delta: score
    )

    # Update match player score
    match_player.increment!(:score, score)

    # Advance turn
    match.advance_turn!
  end

  def evaluate_targets(impact_xyz)
    map = match.map
    map.map_targets.where(destroyed: false).map do |target|
      distance = calculate_distance(impact_xyz, target.coordinates)

      result = Artillery::Engines::TargetResolution.evaluate_single(
        distance: distance,
        material: target.material
      )

      score = Artillery::Engines::DamageEvaluator.call(
        result: result,
        distance: distance
      )

      if result == :destroyed || result == :damaged
        target.take_damage!(100)
      end

      {
        target_id: target.id,
        result: result,
        distance: distance.round(2),
        score: score
      }
    end
  end

  def calculate_distance(pos1, pos2)
    Math.sqrt(
      (pos1[0] - pos2[0])**2 +
      (pos1[1] - pos2[1])**2 +
      (pos1[2] - pos2[2])**2
    )
  end

  def broadcast_turn_result
    Turbo::StreamsChannel.broadcast_append_to(
      "match_#{match.id}",
      target: "turn_history",
      partial: "turns/turn_result",
      locals: { turn: self }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "match_#{match.id}_trajectory",
      target: "trajectory_viewer",
      partial: "turns/trajectory",
      locals: { turn: self }
    )
  end
end
```

### Controllers

```ruby
# app/controllers/matches_controller.rb
class MatchesController < ApplicationController
  before_action :set_match, only: [:show, :leave]

  def index
    @matches = Match.where(state: [:setup, :in_progress])
                    .includes(:players)
                    .order(created_at: :desc)
  end

  def show
    @current_match_player = @match.match_players.find_by(player: current_player)
    @is_active = @current_match_player&.is_active_player?
  end

  def new
    @match = Match.new
  end

  def create
    @match = Match.new(match_params)

    if @match.save
      # Creator joins as first player
      @match.match_players.create!(
        player: current_player,
        player_loadout: current_player.player_loadouts.find(params[:loadout_id]),
        position_on_map: { x: -200, y: 0, z: 0 },
        turn_order: 1
      )

      redirect_to @match
    else
      render :new, status: :unprocessable_entity
    end
  end

  def join
    # Join by lobby code
    @match = Match.find_by!(lobby_code: params[:lobby_code].upcase)

    if @match.setup? && @match.players.count < 8 && !@match.players.include?(current_player)
      @match.match_players.create!(
        player: current_player,
        player_loadout: current_player.player_loadouts.find(params[:loadout_id]),
        position_on_map: { x: 200 * @match.players.count, y: 0, z: 0 },
        turn_order: @match.match_players.count + 1
      )

      redirect_to @match, notice: "Joined match #{@match.lobby_code}"
    else
      redirect_to matches_path, alert: "Cannot join this match"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to matches_path, alert: "Match not found with code: #{params[:lobby_code]}"
  end

  def start
    @match = Match.find(params[:id])

    if @match.start!
      redirect_to @match, notice: "Match started!"
    else
      redirect_to @match, alert: "Cannot start match"
    end
  end

  def leave
    match_player = @match.match_players.find_by(player: current_player)
    match_player&.destroy

    redirect_to matches_path
  end

  private

  def set_match
    @match = Match.includes(:players, :map, :turns).find(params[:id])
  end

  def match_params
    params.require(:match).permit(:turn_limit, match_config: {})
  end

  def current_player
    @current_player ||= Player.find(session[:player_id])
  end
end

# app/controllers/turns_controller.rb
class TurnsController < ApplicationController
  before_action :set_match

  def create
    @match_player = @match.active_match_player

    unless @match_player&.player == current_player
      return render json: { error: "Not your turn" }, status: :forbidden
    end

    @turn = @match.turns.create!(
      match_player: @match_player,
      turn_number: @match.current_turn_number,
      player_input: turn_params
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @match }
    end
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end

  def turn_params
    params.require(:turn).permit(:elevation, :powder_charges, :deflection).to_h
  end

  def current_player
    @current_player ||= Player.find(session[:player_id])
  end
end
```

### Views (ERB + Turbo)

```erb
<!-- app/views/matches/show.html.erb -->
<%= turbo_stream_from "match_#{@match.id}" %>

<div class="grid grid-cols-12 gap-4 h-screen p-4" data-controller="match">
  <!-- Left Sidebar: Match Info & Players -->
  <div class="col-span-3 space-y-4">
    <%= turbo_frame_tag "match_state", data: { turbo_action: "advance" } do %>
      <%= render "matches/state", match: @match %>
    <% end %>

    <%= turbo_frame_tag "players_list" do %>
      <%= render "matches/players_list", match: @match %>
    <% end %>
  </div>

  <!-- Center: Map & Trajectory Viewer -->
  <div class="col-span-6">
    <div class="bg-gray-800 rounded-lg p-4 h-full">
      <%= turbo_frame_tag "trajectory_viewer" do %>
        <%= render "turns/trajectory", turn: @match.turns.last if @match.turns.any? %>
      <% end %>

      <canvas id="map-canvas"
              class="w-full h-full"
              data-controller="map-viewer"
              data-map-viewer-map-value="<%= @match.map.to_json %>"
              data-map-viewer-targets-value="<%= @match.map.map_targets.to_json %>">
      </canvas>
    </div>
  </div>

  <!-- Right Sidebar: Controls or Spectator View -->
  <div class="col-span-3">
    <% if @is_active %>
      <%= turbo_frame_tag "turn_input" do %>
        <%= render "turns/input_form", match: @match, match_player: @current_match_player %>
      <% end %>
    <% else %>
      <%= turbo_frame_tag "spectator_view" do %>
        <%= render "matches/spectator_view", match: @match, active_player: @match.current_player %>
      <% end %>
    <% end %>

    <!-- Turn History -->
    <div class="mt-4 bg-gray-900 rounded-lg p-4 overflow-y-auto max-h-96">
      <h3 class="text-lg font-bold mb-2">Turn History</h3>
      <div id="turn_history">
        <%= render @match.turns.order(created_at: :desc) %>
      </div>
    </div>
  </div>
</div>

<!-- app/views/turns/_input_form.html.erb -->
<div class="bg-gray-900 rounded-lg p-4">
  <h3 class="text-xl font-bold mb-4">Your Turn!</h3>

  <%= form_with model: Turn.new, url: match_turns_path(match),
                data: { turbo_frame: "_top" } do |f| %>

    <div class="mb-4">
      <%= f.label :elevation, "Elevation (clicks)", class: "block text-sm font-medium" %>
      <%= f.number_field :elevation,
                         class: "mt-1 block w-full rounded-md bg-gray-800 border-gray-700",
                         min: 0, max: 45 %>
    </div>

    <div class="mb-4">
      <%= f.label :powder_charges, "Powder Charges", class: "block text-sm font-medium" %>
      <%= f.number_field :powder_charges,
                         class: "mt-1 block w-full rounded-md bg-gray-800 border-gray-700",
                         min: 1, max: 5 %>
    </div>

    <div class="mb-4">
      <%= f.label :deflection, "Deflection (turns)", class: "block text-sm font-medium" %>
      <%= f.number_field :deflection,
                         class: "mt-1 block w-full rounded-md bg-gray-800 border-gray-700",
                         min: -8, max: 8 %>
    </div>

    <%= f.submit "Fire!", class: "w-full bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded" %>
  <% end %>

  <!-- Platform UI Representation -->
  <div class="mt-4 border-t border-gray-700 pt-4">
    <%= render "shared/platform_ui", match_player: match_player %>
  </div>
</div>

<!-- app/views/matches/_spectator_view.html.erb -->
<div class="bg-gray-900 rounded-lg p-4">
  <h3 class="text-xl font-bold mb-4">
    <%= active_player.username %>'s Turn
  </h3>

  <p class="text-gray-400 text-sm mb-4">
    Waiting for player to fire...
  </p>

  <!-- Non-interactive version of active player's platform -->
  <div class="opacity-75 pointer-events-none">
    <%= render "shared/platform_ui", match_player: match.active_match_player %>
  </div>
</div>

<!-- app/views/turns/_trajectory.html.erb -->
<div data-controller="trajectory-animator"
     data-trajectory-animator-trace-value="<%= turn.ballistic_result['trace'].to_json %>"
     data-trajectory-animator-impact-value="<%= turn.ballistic_result['impact_xyz'].to_json %>">
  <canvas id="trajectory-canvas" class="w-full" height="400"></canvas>
</div>
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/map_viewer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    map: Object,
    targets: Array
  }

  connect() {
    this.canvas = this.element
    this.ctx = this.canvas.getContext('2d')
    this.render()
  }

  render() {
    const { boundaries } = this.mapValue
    const targets = this.targetsValue

    // Clear canvas
    this.ctx.fillStyle = '#2d3748'
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height)

    // Draw grid
    this.drawGrid(boundaries)

    // Draw targets
    targets.forEach(target => {
      if (!target.destroyed) {
        this.drawTarget(target)
      }
    })
  }

  drawGrid(boundaries) {
    this.ctx.strokeStyle = '#4a5568'
    this.ctx.lineWidth = 1

    // Draw grid lines every 100m
    for (let x = boundaries.min_x; x <= boundaries.max_x; x += 100) {
      const screenX = this.worldToScreenX(x, boundaries)
      this.ctx.beginPath()
      this.ctx.moveTo(screenX, 0)
      this.ctx.lineTo(screenX, this.canvas.height)
      this.ctx.stroke()
    }
  }

  drawTarget(target) {
    const x = this.worldToScreenX(target.position.x, this.mapValue.boundaries)
    const y = this.worldToScreenY(target.position.y, this.mapValue.boundaries)

    // Color based on material
    const colors = {
      paper: '#f6e05e',
      wood: '#d69e2e',
      metal: '#718096'
    }

    this.ctx.fillStyle = colors[target.material]
    this.ctx.beginPath()
    this.ctx.arc(x, y, 8, 0, 2 * Math.PI)
    this.ctx.fill()
  }

  worldToScreenX(worldX, boundaries) {
    const width = boundaries.max_x - boundaries.min_x
    return ((worldX - boundaries.min_x) / width) * this.canvas.width
  }

  worldToScreenY(worldY, boundaries) {
    const height = boundaries.max_y - boundaries.min_y
    return ((worldY - boundaries.min_y) / height) * this.canvas.height
  }
}

// app/javascript/controllers/trajectory_animator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    trace: Array,
    impact: Array
  }

  connect() {
    this.canvas = this.element.querySelector('canvas')
    this.ctx = this.canvas.getContext('2d')
    this.animateTrajectory()
  }

  animateTrajectory() {
    const trace = this.traceValue
    let index = 0

    // Clear canvas
    this.ctx.fillStyle = '#1a202c'
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height)

    const animate = () => {
      if (index >= trace.length) {
        this.drawImpact()
        return
      }

      const point = trace[index]
      this.drawTrajectoryPoint(point, index)
      index++

      setTimeout(() => requestAnimationFrame(animate), 16) // ~60fps
    }

    animate()
  }

  drawTrajectoryPoint(point, index) {
    const [x, y, z] = point

    // Project 3D to 2D (simple orthographic)
    const screenX = (x + 500) / 10  // Scale to canvas
    const screenY = 400 - (z * 2)    // Flip Y, scale Z

    // Draw point
    this.ctx.fillStyle = index === 0 ? '#f56565' : '#fc8181'
    this.ctx.beginPath()
    this.ctx.arc(screenX, screenY, 3, 0, 2 * Math.PI)
    this.ctx.fill()

    // Draw line from previous point
    if (index > 0) {
      const prev = this.traceValue[index - 1]
      const prevX = (prev[0] + 500) / 10
      const prevY = 400 - (prev[2] * 2)

      this.ctx.strokeStyle = '#fc8181'
      this.ctx.lineWidth = 2
      this.ctx.beginPath()
      this.ctx.moveTo(prevX, prevY)
      this.ctx.lineTo(screenX, screenY)
      this.ctx.stroke()
    }
  }

  drawImpact() {
    const [x, y, z] = this.impactValue
    const screenX = (x + 500) / 10
    const screenY = 400 - (z * 2)

    // Draw explosion effect
    this.ctx.fillStyle = '#f56565'
    this.ctx.globalAlpha = 0.5
    this.ctx.beginPath()
    this.ctx.arc(screenX, screenY, 20, 0, 2 * Math.PI)
    this.ctx.fill()
    this.ctx.globalAlpha = 1.0
  }
}

// app/javascript/controllers/match_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Subscribe to match updates via Turbo Streams
    console.log("Match view connected")
  }

  disconnect() {
    console.log("Match view disconnected")
  }
}
```

### Benefits of Approach A

1. **Simple to Understand** - Straightforward Rails conventions, easy for new developers
2. **Fast to Implement** - Minimal architectural complexity, get to playable prototype quickly
3. **JSONB Flexibility** - Can evolve match state without migrations
4. **Turbo Integration** - Rails 8 Turbo Streams work naturally with this pattern
5. **Single Source of Truth** - Match model owns all state, no coordination needed

### Tradeoffs of Approach A

1. **Tightly Coupled** - Match model becomes "god object" with many responsibilities
2. **Limited Replay** - Turn history exists but reconstructing past states requires work
3. **Testing Complexity** - Need to test entire match lifecycle, hard to isolate behaviors
4. **JSONB Brittleness** - Schema-less data can cause runtime errors if structure changes
5. **Concurrency Issues** - Multiple players acting simultaneously requires careful locking
6. **Difficult to Extend** - Adding new game modes or rules requires touching Match model

---

## Approach B: Event-Sourced Turn History

### Philosophy

"Every action is an event" - Build match state as a stream of immutable events. Full auditability, perfect replays, time-travel debugging.

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                  Match (Aggregate Root)                      │
│  - id: UUID                                                  │
│  - state: enum (derived from events)                         │
│  - version: integer (optimistic locking)                     │
│  - created_at                                                │
└──────────────────────────────────────────────────────────────┘
                          │
                          └─── has_many :events (append-only)

┌──────────────────────────────────────────────────────────────┐
│                      MatchEvent (Event Store)                │
│  - id: UUID                                                  │
│  - match_id: FK                                              │
│  - event_type: string (MatchCreated, PlayerJoined, etc)      │
│  - event_data: JSONB (payload)                               │
│  - metadata: JSONB (user_id, timestamp, etc)                 │
│  - sequence_number: integer (auto-increment per match)       │
│  - created_at: timestamp (immutable)                         │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│              MatchProjection (Read Model)                    │
│  - match_id: FK (unique)                                     │
│  - current_state: JSONB (reconstructed from events)          │
│  - last_event_sequence: integer                              │
│  - updated_at                                                │
└──────────────────────────────────────────────────────────────┘
```

### Event Types

```ruby
# lib/artillery/match_events.rb
module Artillery
  module MatchEvents
    class BaseEvent
      attr_reader :event_type, :event_data, :metadata

      def initialize(event_data:, metadata: {})
        @event_type = self.class.name.demodulize
        @event_data = event_data
        @metadata = metadata.merge(timestamp: Time.current)
      end

      def to_h
        {
          event_type: event_type,
          event_data: event_data,
          metadata: metadata
        }
      end
    end

    # Match Lifecycle Events
    class MatchCreated < BaseEvent; end
    class PlayerJoined < BaseEvent; end
    class PlayerLeft < BaseEvent; end
    class MatchStarted < BaseEvent; end
    class MatchCompleted < BaseEvent; end

    # Map Events
    class MapGenerated < BaseEvent; end
    class TargetSpawned < BaseEvent; end
    class TargetDestroyed < BaseEvent; end

    # Turn Events
    class TurnStarted < BaseEvent; end
    class InputSubmitted < BaseEvent; end
    class SimulationCompleted < BaseEvent; end
    class TargetsEvaluated < BaseEvent; end
    class ScoreUpdated < BaseEvent; end
    class TurnCompleted < BaseEvent; end
  end
end
```

### Database Schema

```ruby
# Migration: Create matches (event-sourced)
class CreateMatchesEventSourced < ActiveRecord::Migration[8.1]
  def change
    create_table :matches, id: :uuid do |t|
      t.integer :version, default: 0, null: false
      t.datetime :created_at, null: false
    end

    add_index :matches, :version
  end
end

# Migration: Create match_events (event store)
class CreateMatchEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :match_events, id: :uuid do |t|
      t.references :match, type: :uuid, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :event_data, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false
      t.integer :sequence_number, null: false
      t.datetime :created_at, null: false
    end

    add_index :match_events, [:match_id, :sequence_number], unique: true
    add_index :match_events, :event_type
    add_index :match_events, :created_at
  end
end

# Migration: Create match_projections (read model)
class CreateMatchProjections < ActiveRecord::Migration[8.1]
  def change
    create_table :match_projections do |t|
      t.references :match, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :current_state, default: {}, null: false
      t.integer :last_event_sequence, default: 0, null: false
      t.datetime :updated_at, null: false
    end

    add_index :match_projections, :last_event_sequence
  end
end
```

### Model Implementations

```ruby
# app/models/match.rb (Event-Sourced)
class Match < ApplicationRecord
  has_many :events, class_name: 'MatchEvent', dependent: :destroy
  has_one :projection, class_name: 'MatchProjection', dependent: :destroy

  after_create :initialize_projection

  # Command: Append event to stream
  def apply_event(event)
    transaction do
      # Optimistic locking
      lock!

      # Create event record
      events.create!(
        event_type: event.event_type,
        event_data: event.event_data,
        metadata: event.metadata,
        sequence_number: events.count + 1
      )

      # Increment version
      increment!(:version)

      # Update projection
      projection.apply_event(event)
    end
  rescue ActiveRecord::StaleObjectError
    retry
  end

  # Query: Reconstruct state from events
  def reconstruct_state_at(sequence_number = nil)
    event_stream = sequence_number ?
      events.where('sequence_number <= ?', sequence_number) :
      events

    state = initial_state
    event_stream.order(:sequence_number).each do |event|
      state = apply_event_to_state(state, event)
    end
    state
  end

  # Query: Get current state from projection (fast)
  def current_state
    projection.current_state
  end

  # Commands
  def create_match!(creator:, config:)
    apply_event(Artillery::MatchEvents::MatchCreated.new(
      event_data: {
        creator_id: creator.id,
        config: config
      }
    ))
  end

  def add_player!(player:, loadout:, position:)
    apply_event(Artillery::MatchEvents::PlayerJoined.new(
      event_data: {
        player_id: player.id,
        loadout_id: loadout.id,
        position: position
      }
    ))
  end

  def start_match!
    apply_event(Artillery::MatchEvents::MatchStarted.new(
      event_data: {
        started_at: Time.current
      }
    ))
  end

  def submit_turn!(player:, input:)
    # Multi-event turn sequence
    apply_event(Artillery::MatchEvents::InputSubmitted.new(
      event_data: {
        player_id: player.id,
        turn_number: current_state['current_turn'],
        input: input
      }
    ))

    # Simulation happens in background job
    TurnSimulationJob.perform_later(id)
  end

  private

  def initial_state
    {
      'state' => 'created',
      'players' => {},
      'map' => nil,
      'current_turn' => 0,
      'current_player_id' => nil,
      'scores' => {}
    }
  end

  def apply_event_to_state(state, event)
    case event.event_type
    when 'MatchCreated'
      state.merge('state' => 'setup', 'config' => event.event_data['config'])
    when 'PlayerJoined'
      players = state['players'].dup
      players[event.event_data['player_id']] = {
        'loadout_id' => event.event_data['loadout_id'],
        'position' => event.event_data['position'],
        'turn_order' => players.count + 1
      }
      state.merge('players' => players)
    when 'MatchStarted'
      first_player = state['players'].keys.first
      state.merge(
        'state' => 'in_progress',
        'current_player_id' => first_player,
        'current_turn' => 1
      )
    when 'SimulationCompleted'
      state # More complex state transition logic here
    else
      state
    end
  end

  def initialize_projection
    create_projection!(current_state: initial_state)
  end
end

# app/models/match_event.rb
class MatchEvent < ApplicationRecord
  belongs_to :match

  validates :event_type, presence: true
  validates :sequence_number, uniqueness: { scope: :match_id }

  # Events are immutable
  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  def payload
    @payload ||= event_data.deep_symbolize_keys
  end
end

# app/models/match_projection.rb
class MatchProjection < ApplicationRecord
  belongs_to :match

  def apply_event(event)
    new_state = match.send(:apply_event_to_state, current_state, event)
    update!(
      current_state: new_state,
      last_event_sequence: event.sequence_number
    )
  end

  def state_enum
    current_state['state']
  end

  def players
    current_state['players']
  end

  def current_player_id
    current_state['current_player_id']
  end

  def current_turn
    current_state['current_turn']
  end
end

# app/jobs/turn_simulation_job.rb
class TurnSimulationJob < ApplicationJob
  queue_as :default

  def perform(match_id)
    match = Match.find(match_id)

    # Get latest input event
    input_event = match.events
      .where(event_type: 'InputSubmitted')
      .where('sequence_number > ?', match.projection.last_event_sequence)
      .order(:sequence_number)
      .last

    return unless input_event

    # Run simulation
    player_id = input_event.payload[:player_id]
    player_input = input_event.payload[:input]

    # ... (similar simulation logic as Approach A)

    # Apply simulation result event
    match.apply_event(Artillery::MatchEvents::SimulationCompleted.new(
      event_data: {
        player_id: player_id,
        ballistic_result: result,
        turn_number: input_event.payload[:turn_number]
      }
    ))

    # Apply targets evaluated event
    match.apply_event(Artillery::MatchEvents::TargetsEvaluated.new(
      event_data: {
        targets_hit: targets_hit
      }
    ))

    # Apply score updated event
    match.apply_event(Artillery::MatchEvents::ScoreUpdated.new(
      event_data: {
        player_id: player_id,
        score_delta: score
      }
    ))
  end
end
```

### Benefits of Approach B

1. **Perfect Replay** - Reconstruct any past state by replaying events up to that point
2. **Audit Trail** - Complete history of every action, great for debugging and analytics
3. **Time Travel** - Can "rewind" matches for analysis or dispute resolution
4. **Eventual Consistency** - Projections can be rebuilt from events if corrupted
5. **Testability** - Event handlers can be tested in isolation
6. **Extensibility** - New projections can be added without changing event store
7. **Microservice Ready** - Events can be published to message bus for other services

### Tradeoffs of Approach B

1. **Complexity** - Much more complex than traditional CRUD, steep learning curve
2. **Performance** - Reconstructing state from events is slow (mitigated by projections)
3. **Storage** - Event store grows indefinitely (need archival/snapshotting strategy)
4. **Eventual Consistency** - Projections may lag behind events briefly
5. **Schema Evolution** - Changing event structure requires versioning and migration
6. **Overkill** - May be unnecessary complexity for a simple game
7. **Debugging** - Harder to debug when state is derived from many events

---

## Approach C: Service-Oriented Game State

### Philosophy

"Separate concerns cleanly" - Split game state into specialized services. Match orchestrates, but delegates to domain services.

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Match (Orchestrator)                      │
│  - id, state, current_turn_number                            │
│  - Delegates to services, owns no complex state              │
└──────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌─────────────┐  ┌──────────────┐  ┌────────────────┐
│MatchPlayers │  │  GameMap     │  │  TurnHistory   │
│  Service    │  │  Service     │  │  Service       │
└─────────────┘  └──────────────┘  └────────────────┘
```

### Service Layer

```ruby
# app/services/match_players_service.rb
class MatchPlayersService
  def initialize(match)
    @match = match
  end

  def add_player(player:, loadout:, position:)
    @match.match_players.create!(
      player: player,
      player_loadout: loadout,
      position_on_map: position,
      turn_order: next_turn_order
    )
  end

  def instantiate_all_runtimes!
    @match.match_players.each(&:instantiate_runtimes!)
  end

  def active_player
    @match.match_players.find_by(player: @match.current_player)
  end

  def next_player
    current_order = active_player.turn_order
    next_order = (current_order % @match.match_players.count) + 1
    @match.match_players.find_by(turn_order: next_order)
  end

  def scores
    @match.match_players.pluck(:player_id, :score).to_h
  end

  private

  def next_turn_order
    @match.match_players.maximum(:turn_order).to_i + 1
  end
end

# app/services/game_map_service.rb
class GameMapService
  def initialize(match)
    @match = match
    @map = match.map || match.create_map!
  end

  def spawn_targets!(count: 5)
    count.times do
      @map.map_targets.create!(
        position: random_position,
        target_type: 'stationary',
        material: ['paper', 'wood'].sample
      )
    end
  end

  def evaluate_impact(impact_xyz)
    @map.map_targets.where(destroyed: false).map do |target|
      distance = calculate_distance(impact_xyz, target.coordinates)

      {
        target: target,
        distance: distance,
        result: determine_result(distance, target.material)
      }
    end
  end

  def destroy_target!(target_id)
    target = @map.map_targets.find(target_id)
    target.update!(destroyed: true)
  end

  private

  def random_position
    {
      'x' => rand(100..400),
      'y' => rand(-200..200),
      'z' => 0
    }
  end

  def calculate_distance(pos1, pos2)
    # Same as before
  end

  def determine_result(distance, material)
    # Use existing TargetResolution logic
    Artillery::Engines::TargetResolution.evaluate_single(
      distance: distance,
      material: material
    )
  end
end

# app/services/turn_history_service.rb
class TurnHistoryService
  def initialize(match)
    @match = match
  end

  def record_turn(match_player:, input:, result:, targets_hit:, score:)
    @match.turns.create!(
      match_player: match_player,
      turn_number: @match.current_turn_number,
      player_input: input,
      resolved_attributes: result[:resolved],
      ballistic_result: result[:ballistic],
      targets_hit: targets_hit,
      score_delta: score
    )
  end

  def latest_turn
    @match.turns.order(created_at: :desc).first
  end

  def turns_for_player(player_id)
    @match.turns.joins(:match_player)
      .where(match_players: { player_id: player_id })
      .order(:turn_number)
  end

  def turn_summary
    @match.turns.group(:match_player_id).count
  end
end

# app/services/turn_executor_service.rb
class TurnExecutorService
  def initialize(match:, match_player:, input:)
    @match = match
    @match_player = match_player
    @input = input
  end

  def execute!
    result = run_simulation
    targets = evaluate_targets(result[:ballistic][:impact_xyz])
    score = calculate_score(targets)

    # Record turn
    TurnHistoryService.new(@match).record_turn(
      match_player: @match_player,
      input: @input,
      result: result,
      targets_hit: targets,
      score: score
    )

    # Update player score
    @match_player.increment!(:score, score)

    # Destroy hit targets
    map_service = GameMapService.new(@match)
    targets.each do |hit|
      if hit[:result] == :destroyed
        map_service.destroy_target!(hit[:target_id])
      end
    end

    # Advance turn
    @match.advance_turn!

    result
  end

  private

  def run_simulation
    # Pipeline resolution
    resolver = Artillery::Mechanisms::PipelineResolver.new(
      @match_player.runtimes,
      @input.symbolize_keys
    )

    resolved = resolver.ballistic_attributes

    # Ballistic simulation
    engine = Artillery::Engines::Ballistic3D.new(
      before_tick_hooks: resolver.engine_hooks,
      affectors: resolver.engine_affectors.map { |a| ->(state, tick) { a.call(state, tick) } }
    )

    ballistic = engine.simulate(resolved)

    { resolved: resolved.to_h, ballistic: ballistic }
  end

  def evaluate_targets(impact_xyz)
    GameMapService.new(@match).evaluate_impact(impact_xyz).map do |eval|
      {
        target_id: eval[:target].id,
        result: eval[:result],
        distance: eval[:distance].round(2),
        score: calculate_target_score(eval)
      }
    end
  end

  def calculate_score(targets)
    targets.sum { |t| t[:score] }
  end

  def calculate_target_score(evaluation)
    Artillery::Engines::DamageEvaluator.call(
      result: evaluation[:result],
      distance: evaluation[:distance]
    )
  end
end
```

### Controllers (Simplified)

```ruby
# app/controllers/matches_controller.rb
class MatchesController < ApplicationController
  def create
    @match = Match.create!(match_params)

    # Use service to add creator
    service = MatchPlayersService.new(@match)
    service.add_player(
      player: current_player,
      loadout: current_player.player_loadouts.find(params[:loadout_id]),
      position: { x: -200, y: 0, z: 0 }
    )

    # Generate map
    map_service = GameMapService.new(@match)
    map_service.spawn_targets!(count: 5)

    redirect_to @match
  end

  def start
    @match = Match.find(params[:id])

    if @match.can_start?
      # Use service to instantiate runtimes
      MatchPlayersService.new(@match).instantiate_all_runtimes!
      @match.start!
      redirect_to @match
    else
      redirect_to @match, alert: "Cannot start match"
    end
  end
end

# app/controllers/turns_controller.rb
class TurnsController < ApplicationController
  def create
    @match = Match.find(params[:match_id])
    service = MatchPlayersService.new(@match)
    active_player = service.active_player

    unless active_player.player == current_player
      return render json: { error: "Not your turn" }, status: :forbidden
    end

    # Execute turn via service
    executor = TurnExecutorService.new(
      match: @match,
      match_player: active_player,
      input: turn_params
    )

    @result = executor.execute!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @match }
    end
  end

  private

  def turn_params
    params.require(:turn).permit(:elevation, :powder_charges, :deflection).to_h
  end
end
```

### Benefits of Approach C

1. **Clean Separation** - Each service has single responsibility
2. **Testable** - Services can be unit tested in isolation
3. **Maintainable** - Changes localized to specific services
4. **Reusable** - Services can be used across different controllers/contexts
5. **Scalable** - Services can be extracted to separate processes if needed
6. **Understandable** - Clear boundaries between match orchestration and domain logic

### Tradeoffs of Approach C

1. **More Files** - Service layer adds complexity and file count
2. **Indirection** - Need to look through services to understand flow
3. **Over-Engineering** - May be unnecessary abstraction for simple game
4. **Transaction Boundaries** - Need careful thought about where transactions start/end
5. **Service Discovery** - Developers need to know which service handles what

---

## Comparison Matrix

| Aspect | Approach A: Stateful Aggregate | Approach B: Event-Sourced | Approach C: Service-Oriented |
|--------|-------------------------------|---------------------------|------------------------------|
| **Complexity** | Low | High | Medium |
| **Time to Prototype** | Fast (1-2 weeks) | Slow (3-4 weeks) | Medium (2-3 weeks) |
| **Replay Capability** | Limited | Perfect | Good (with history) |
| **Testability** | Medium (integration heavy) | High (unit testable events) | High (unit testable services) |
| **Scalability** | Medium | High | High |
| **Learning Curve** | Low (standard Rails) | High (event sourcing patterns) | Medium (service patterns) |
| **Maintenance** | Medium (god object risk) | High (event versioning) | Low (clear boundaries) |
| **Real-time Updates** | Easy (Turbo Streams) | Easy (Turbo Streams) | Easy (Turbo Streams) |
| **Audit Trail** | Basic (turn history) | Complete (all events) | Good (service logs) |
| **Debugging** | Easy (inspect DB) | Hard (replay events) | Medium (trace through services) |
| **Best For** | MVP, Learning | Production, Analytics | Production, Team Projects |

---

## UI Mockup Descriptions

### Lobby & Match Joining

#### Match List / Lobby View

```
┌─────────────────────────────────────────────────────────────────┐
│  Artillery Matches                          [Create New Match]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Your Active Matches:                                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Match ABC123  •  Turn 5/10  •  Your Turn!  [View →]       │ │
│  │ Players: You, Player2, Player3                             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Match XYZ789  •  Turn 2/10  •  Waiting for Player2        │ │
│  │ Players: You, Player2                          [View →]   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Join a Match:                                                  │
│  ┌──────────────────────────────────┐                           │
│  │ Enter Match Code: [______]  [Join] │                         │
│  └──────────────────────────────────┘                           │
│                                                                  │
│  Completed Matches:                                             │
│  • Match DEF456 - You won! (350 pts)                            │
│  • Match GHI012 - 2nd place (220 pts)                           │
└─────────────────────────────────────────────────────────────────┘
```

#### Create Match View

```
┌─────────────────────────────────────────────────────────────────┐
│  Create New Match                                     [Cancel]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Select Your Loadout:                                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ○  My QF 18-Pounder      (Complete)                       │ │
│  │ ●  Precision Setup        (Complete)                       │ │
│  │ ○  Long Range Build       (Incomplete - Missing barrel)   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Match Settings:                                                │
│  Turn Limit: [10 ▼]                                             │
│  Max Players: [4 ▼]                                             │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   [Create Match]                           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  After creating, share the match code with friends to join!     │
└─────────────────────────────────────────────────────────────────┘
```

#### Match Lobby (Setup Phase)

```
┌─────────────────────────────────────────────────────────────────┐
│  Match Lobby: ABC123                 [Leave] [Start Match]      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Share this code with friends: ABC123                           │
│  [Copy Code]                                                    │
│                                                                  │
│  Players (2/4):                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ✓  You          QF 18-Pounder (Precision Setup)           │ │
│  │ ✓  Player2      QF 18-Pounder (Long Range)                │ │
│  │ ○  Waiting...                                              │ │
│  │ ○  Waiting...                                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Settings:                                                      │
│  • Turn Limit: 10                                               │
│  • Map: Random Field (1000m x 1000m)                            │
│                                                                  │
│  [Start Match] (requires at least 2 players)                    │
└─────────────────────────────────────────────────────────────────┘
```

### In-Match UI

#### Match View Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Match ABC123  •  Turn 5/10                         [Leave]      │
├───────────┬─────────────────────────────────┬───────────────────┤
│           │                                 │                   │
│  PLAYERS  │      MAP & TRAJECTORY           │   YOUR TURN /     │
│           │                                 │   WAITING         │
│  Player1  │  ┌─────────────────────────────┐│                   │
│  ⭐ 250pts │  │                             ││  [Elevation: __] │
│           │  │      [Trajectory Arc]       ││                   │
│  Player2  │  │                             ││  [Powder: ____]  │
│  ☆ 180pts │  │    🎯  🎯        🎯         ││                   │
│ (Active)  │  │                             ││  [Deflection: _] │
│           │  │  🔫 Player1    Player2 🔫   ││                   │
│  Player3  │  └─────────────────────────────┘│  [ FIRE! ]       │
│  ☆ 120pts │                                 │                   │
│           │  ┌─────────────────────────────┐│  ┌──────────────┐│
│           │  │   Platform Visualization    ││  │Turn History  ││
│ [Start]   │  │   (Active Player's UI)      ││  │Turn 5: +50pt ││
│           │  └─────────────────────────────┘│  │Turn 4: Miss  ││
│           │                                 │  └──────────────┘│
└───────────┴─────────────────────────────────┴───────────────────┘
```

#### Active Player View (Your Turn)

The right panel shows **interactive controls**:

```
┌───────────────────────────┐
│     YOUR TURN!            │
├───────────────────────────┤
│                           │
│  Elevation Control        │
│  ┌─────────────────────┐  │
│  │  [  15 clicks   ]  │  │
│  │  ├─────●──────────┤  │  │
│  └─────────────────────┘  │
│                           │
│  Powder Charges           │
│  ┌─────────────────────┐  │
│  │  [ ● ● ○ ○ ○ ]    │  │  (3/5 charges)
│  └─────────────────────┘  │
│                           │
│  Deflection               │
│  ┌─────────────────────┐  │
│  │  ├───●──────────┤    │  │  (2° right)
│  └─────────────────────┘  │
│                           │
│  ┌─────────────────────┐  │
│  │    🔥 FIRE! 🔥      │  │
│  └─────────────────────┘  │
│                           │
│  ┌─────────────────────┐  │
│  │  QF 18-Pounder      │  │
│  │  Mk II Edwardian    │  │
│  │                     │  │
│  │  [Dial Drawing]     │  │
│  │  [Breech Drawing]   │  │
│  └─────────────────────┘  │
└───────────────────────────┘
```

#### Waiting View (Not Your Turn)

The right panel shows **match status** for async play:

```
┌───────────────────────────┐
│  Player2's Turn           │
├───────────────────────────┤
│                           │
│  Waiting for Player2      │
│  to take their turn...    │
│                           │
│  You can:                 │
│  • Log off and return     │
│    later                  │
│  • Review turn history    │
│  • View the map           │
│                           │
│  You'll be notified when  │
│  it's your turn!          │
│                           │
│  ┌─────────────────────┐  │
│  │ Your Last Turn:     │  │
│  │                     │  │
│  │ Turn 3: Hit target  │  │
│  │ +50 points          │  │
│  │ [View Replay]       │  │
│  └─────────────────────┘  │
│                           │
│  Recent Activity:         │
│  • Turn 4: Player1 hit    │
│  • Turn 3: You hit        │
│  • Turn 2: Player2 miss   │
└───────────────────────────┘
```

#### Trajectory Visualization

Canvas-based 3D trajectory display:

```
┌───────────────────────────────────────┐
│  Side View                  Top View  │
│  ▲                          ┌───────┐ │
│  │   ┌──────┐               │       │ │
│  │   │  •   │               │   •   │ │  • = shell position
│  │  •│      │               │  /    │ │  Red arc = trajectory
│  │ • │      │  ●            │ ● ─── │ │  ● = impact
│  │•  │      │  Target       │Target │ │  🎯 = target
│ 🔫───┴──────┴───────────→   └───────┘ │
│              Distance                 │
└───────────────────────────────────────┘
```

---

## Recommended Approach: **Approach A (Stateful Match Aggregate)**

### Rationale

For Artillery's **first playable multiplayer version**, Approach A is recommended because:

1. **Speed to Playable** - Can have multiplayer working in 1-2 weeks
2. **Rails Conventions** - Familiar patterns, easy for Rails developers
3. **Sufficient for MVP** - Turn history and JSONB provide adequate replay capability
4. **Easy to Evolve** - Can refactor to Approach B or C later if needed
5. **Focus on Gameplay** - Spend time on fun mechanics, not infrastructure

### Migration Path

If the game grows and needs more sophisticated features:

**Phase 1** (Now): Implement Approach A
- Get multiplayer working
- Validate gameplay mechanics
- Gather user feedback

**Phase 2** (6 months): Add Services (Partial Approach C)
- Extract MatchPlayersService, GameMapService
- Keep Match model as orchestrator
- Improve testability

**Phase 3** (12 months): Consider Event Sourcing (Approach B)
- If analytics/replay becomes critical
- If audit trail is required for tournaments
- If microservice architecture emerges

---

## Implementation Timeline (Approach A)

### Week 1: Core Models & Migrations

- [ ] Remove email from Player model
- [ ] Create Match, MatchPlayer, Map, MapTarget, Turn models
- [ ] Write migrations
- [ ] Set up model associations
- [ ] Write model validations
- [ ] Basic model tests

### Week 2: Match Lifecycle & Turn Execution

- [ ] Match state machine (setup → in_progress → completed)
- [ ] Turn execution logic (pipeline → ballistic → evaluation)
- [ ] Runtime instantiation and freezing
- [ ] Turn advancement logic
- [ ] Integration tests for full turn flow

### Week 3: Controllers & Views

- [ ] MatchesController (index, show, create, join, start)
- [ ] TurnsController (create)
- [ ] Match list view
- [ ] Match show view (with Turbo Frames)
- [ ] Turn input form
- [ ] Spectator view partial

### Week 4: Real-Time UI & Polish

- [ ] Turbo Streams for match state updates
- [ ] Stimulus controller for map viewer
- [ ] Stimulus controller for trajectory animation
- [ ] Platform UI component rendering
- [ ] Turn history display
- [ ] CSS/Tailwind styling

### Week 5: Testing & Refinement

- [ ] Full integration tests (2+ player match)
- [ ] UI/UX testing
- [ ] Performance testing (N+1 queries, etc.)
- [ ] Bug fixes
- [ ] Documentation

---

## Design Decisions (Finalized)

1. **Turn Timer** - ❌ No turn timers in MVP. Supports asynchronous play (play-by-mail style).
2. **Simultaneous Turns** - 🔮 Future enhancement, not in MVP.
3. **Match Chat** - 🔮 Future enhancement, not in MVP.
4. **Spectators** - 🔮 Future enhancement, not in MVP.
5. **Matchmaking** - ❌ Not in MVP. Using lobby codes/invites for match joining.
6. **Ranked Play** - 🔮 Future enhancement, not in MVP.
7. **Match Archives** - 🔮 Future enhancement. Matches persist but no special archiving/replay system in MVP.

### Play Style: Asynchronous Turn-Based

Players can:
- Submit their turn and log off
- Return hours or days later to take their next turn
- Play synchronously if all players are online (optional)
- Be notified when it's their turn (basic email/notification)

This is similar to classic "play-by-mail" games or modern async games like Words With Friends.

---

**End of Plan**
