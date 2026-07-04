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

ActiveRecord::Schema[8.1].define(version: 2026_07_04_025410) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "consumer_daily_aggregates", force: :cascade do |t|
    t.boolean "complete", default: false, null: false
    t.bigint "consumer_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "market_reading_count", default: 0, null: false
    t.decimal "market_total", precision: 12, scale: 4, default: "0.0", null: false
    t.integer "metering_reading_count", default: 0, null: false
    t.decimal "metering_total", precision: 12, scale: 4, default: "0.0", null: false
    t.decimal "solar_total", precision: 12, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_id", "date"], name: "index_daily_aggregates_on_consumer_and_date", unique: true
    t.index ["consumer_id"], name: "index_consumer_daily_aggregates_on_consumer_id"
  end

  create_table "consumers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "house_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_consumers_on_house_id"
  end

  create_table "houses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "imports", force: :cascade do |t|
    t.date "begin_date", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "finished_at"
    t.bigint "house_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["house_id", "created_at"], name: "index_imports_on_house_id_and_created_at"
    t.index ["house_id"], name: "index_imports_on_house_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "consumer_id", null: false
    t.datetime "created_at", null: false
    t.string "location_id", null: false
    t.integer "location_type", null: false
    t.datetime "updated_at", null: false
    t.index ["consumer_id", "location_type"], name: "index_locations_on_consumer_id_and_location_type", unique: true
    t.index ["consumer_id"], name: "index_locations_on_consumer_id"
    t.index ["location_id"], name: "index_locations_on_location_id", unique: true
  end

  create_table "readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.bigint "location_id", null: false
    t.string "quality", default: "TRUE", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 4, null: false
    t.index ["location_id", "starts_at"], name: "index_readings_on_location_id_and_starts_at", unique: true
    t.index ["location_id"], name: "index_readings_on_location_id"
    t.index ["starts_at"], name: "index_readings_on_starts_at"
  end

  add_foreign_key "consumer_daily_aggregates", "consumers"
  add_foreign_key "consumers", "houses"
  add_foreign_key "imports", "houses"
  add_foreign_key "locations", "consumers"
  add_foreign_key "readings", "locations"
end
