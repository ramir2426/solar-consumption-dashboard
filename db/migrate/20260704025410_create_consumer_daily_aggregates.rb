class CreateConsumerDailyAggregates < ActiveRecord::Migration[8.1]
  def change
    create_table :consumer_daily_aggregates do |t|
      t.references :consumer, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :market_total, precision: 12, scale: 4, null: false, default: 0
      t.decimal :metering_total, precision: 12, scale: 4, null: false, default: 0
      t.decimal :solar_total, precision: 12, scale: 4, null: false, default: 0
      t.integer :market_reading_count, null: false, default: 0
      t.integer :metering_reading_count, null: false, default: 0
      t.boolean :complete, null: false, default: false

      t.timestamps
    end

    add_index :consumer_daily_aggregates, [ :consumer_id, :date ], unique: true, name: "index_daily_aggregates_on_consumer_and_date"
  end
end
