class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :consumer, null: false, foreign_key: true
      t.string :location_id, null: false
      t.integer :location_type, null: false

      t.timestamps
    end

    add_index :locations, :location_id, unique: true
    add_index :locations, [ :consumer_id, :location_type ], unique: true
  end
end
