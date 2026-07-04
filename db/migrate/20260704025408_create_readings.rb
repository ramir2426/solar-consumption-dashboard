class CreateReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :readings do |t|
      t.references :location, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.decimal :value, precision: 10, scale: 4, null: false
      t.string :quality, null: false, default: "TRUE"

      t.timestamps
    end

    # One row per interval per location; re-importing the same interval
    # is an upsert on this key rather than a new row.
    add_index :readings, [ :location_id, :starts_at ], unique: true
    add_index :readings, :starts_at
  end
end
