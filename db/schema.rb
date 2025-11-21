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

ActiveRecord::Schema[8.1].define(version: 2025_11_21_171657) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_players_on_email", unique: true
    t.index ["username"], name: "index_players_on_username", unique: true
  end

  add_foreign_key "player_loadout_slots", "player_loadouts"
  add_foreign_key "player_loadout_slots", "player_mechanisms"
  add_foreign_key "player_loadouts", "players"
  add_foreign_key "player_mechanisms", "players"
end
