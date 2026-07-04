class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.references :house, null: false, foreign_key: true
      t.date :begin_date, null: false
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end

    add_index :imports, [ :house_id, :created_at ]
  end
end
