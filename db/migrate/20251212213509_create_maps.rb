class CreateMaps < ActiveRecord::Migration[8.1]
  def change
    create_table :maps do |t|
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.integer :width, null: false, default: 1000
      t.integer :height, null: false, default: 1000
      t.jsonb :terrain_data, null: false, default: {}

      t.timestamps
    end
  end
end
