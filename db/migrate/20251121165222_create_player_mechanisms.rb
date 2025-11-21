class CreatePlayerMechanisms < ActiveRecord::Migration[8.1]
  def change
    create_table :player_mechanisms do |t|
      t.references :player, null: false, foreign_key: true
      t.string :type, null: false              # STI discriminator
      t.string :slot_key, null: false          # :barrel, :elevation_dial, etc.
      t.integer :upgrade_level, default: 0, null: false
      t.jsonb :modifiers, default: {}, null: false
      t.decimal :base_cost, precision: 10, scale: 2
      t.decimal :base_weight, precision: 8, scale: 2  # kg
      t.integer :priority, default: 50, null: false    # Pipeline ordering

      t.timestamps
    end

    add_index :player_mechanisms, [:player_id, :slot_key]
    add_index :player_mechanisms, :type
  end
end
