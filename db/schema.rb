# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_12_215308) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "map_targets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_hit", default: false, null: false
    t.bigint "map_id", null: false
    t.string "name", null: false
    t.integer "points_value", default: 50, null: false
    t.jsonb "position", default: {}, null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["map_id"], name: "index_map_targets_on_map_id"
  end

  create_table "maps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "height", default: 1000, null: false
    t.bigint "match_id", null: false
    t.string "name", null: false
    t.jsonb "terrain_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "width", default: 1000, null: false
    t.index ["match_id"], name: "index_maps_on_match_id", unique: true
  end

  create_table "match_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_host", default: false, null: false
    t.bigint "match_id", null: false
    t.bigint "player_id", null: false
    t.bigint "player_loadout_id", null: false
    t.jsonb "position_on_map", default: {}, null: false
    t.integer "score", default: 0, null: false
    t.integer "turn_order", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id", "player_id"], name: "index_match_players_on_match_id_and_player_id", unique: true
    t.index ["match_id", "turn_order"], name: "index_match_players_on_match_id_and_turn_order"
    t.index ["match_id"], name: "index_match_players_on_match_id"
    t.index ["player_id"], name: "index_match_players_on_player_id"
    t.index ["player_loadout_id"], name: "index_match_players_on_player_loadout_id"
  end

  create_table "match_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_turn_number", default: 0, null: false
    t.bigint "match_id", null: false
    t.integer "turn_limit", default: 10, null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_match_states_on_match_id", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_player_id"
    t.string "lobby_code", limit: 6, null: false
    t.string "status", default: "setup", null: false
    t.datetime "updated_at", null: false
    t.index ["current_player_id"], name: "index_matches_on_current_player_id"
    t.index ["lobby_code"], name: "index_matches_on_lobby_code", unique: true
    t.index ["status"], name: "index_matches_on_status"
  end

  create_table "player_loadout_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_loadout_id", null: false
    t.bigint "player_mechanism_id", null: false
    t.string "slot_key", null: false
    t.datetime "updated_at", null: false
    t.index ["player_loadout_id", "slot_key"], name: "index_loadout_slots_on_loadout_and_slot", unique: true
    t.index ["player_loadout_id"], name: "index_player_loadout_slots_on_player_loadout_id"
    t.index ["player_mechanism_id"], name: "index_player_loadout_slots_on_player_mechanism_id"
  end

  create_table "player_loadouts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.string "engine_type", default: "ballistic_3d", null: false
    t.string "label", null: false
    t.string "platform_type", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "label"], name: "index_player_loadouts_on_player_id_and_label", unique: true
    t.index ["player_id"], name: "index_player_loadouts_on_player_id"
  end

  create_table "player_mechanisms", force: :cascade do |t|
    t.decimal "base_cost", precision: 10, scale: 2
    t.decimal "base_weight", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.jsonb "modifiers", default: {}, null: false
    t.bigint "player_id", null: false
    t.integer "priority", default: 50, null: false
    t.string "slot_key", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "upgrade_level", default: 0, null: false
    t.index ["player_id", "slot_key"], name: "index_player_mechanisms_on_player_id_and_slot_key"
    t.index ["player_id"], name: "index_player_mechanisms_on_player_id"
    t.index ["type"], name: "index_player_mechanisms_on_type"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_players_on_username", unique: true
  end

  create_table "turns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "hit_target", default: false, null: false
    t.jsonb "input_data", default: {}, null: false
    t.bigint "match_id", null: false
    t.bigint "match_player_id", null: false
    t.integer "points_earned", default: 0, null: false
    t.jsonb "result_data", default: {}, null: false
    t.integer "turn_number", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id", "turn_number"], name: "index_turns_on_match_id_and_turn_number"
    t.index ["match_id"], name: "index_turns_on_match_id"
    t.index ["match_player_id"], name: "index_turns_on_match_player_id"
  end

  add_foreign_key "map_targets", "maps"
  add_foreign_key "maps", "matches"
  add_foreign_key "match_players", "matches"
  add_foreign_key "match_players", "player_loadouts"
  add_foreign_key "match_players", "players"
  add_foreign_key "match_states", "matches"
  add_foreign_key "matches", "players", column: "current_player_id"
  add_foreign_key "player_loadout_slots", "player_loadouts"
  add_foreign_key "player_loadout_slots", "player_mechanisms"
  add_foreign_key "player_loadouts", "players"
  add_foreign_key "player_mechanisms", "players"
  add_foreign_key "turns", "match_players"
  add_foreign_key "turns", "matches"
end
