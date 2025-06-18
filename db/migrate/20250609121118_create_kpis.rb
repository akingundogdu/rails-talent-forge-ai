class CreateKpis < ActiveRecord::Migration[7.1]
  def change
    create_table :kpis do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.references :position, null: true, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.decimal :target_value, precision: 10, scale: 2, null: false
      t.decimal :actual_value, precision: 10, scale: 2, default: 0.0
      t.string :measurement_unit, default: 'number'
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :status, default: 0, null: false
      t.boolean :deleted_at, default: false

      t.timestamps
    end
    
    add_index :kpis, [:employee_id, :period_start, :period_end]
    add_index :kpis, [:position_id, :period_start, :period_end]
    add_index :kpis, :status
  end
end
