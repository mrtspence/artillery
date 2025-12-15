class CreateMapTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :map_targets do |t|
      t.references :map, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :position, null: false, default: {}
      t.string :target_type, null: false
      t.boolean :is_hit, null: false, default: false
      t.integer :points_value, null: false, default: 50

      t.timestamps
    end
  end
end
