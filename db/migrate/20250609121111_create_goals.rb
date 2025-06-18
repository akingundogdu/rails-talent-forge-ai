class CreateGoals < ActiveRecord::Migration[7.1]
  def change
    create_table :goals do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.references :performance_review, null: true, foreign_key: true, index: true
      t.string :title, null: false
      t.text :description
      t.decimal :target_value, precision: 10, scale: 2
      t.decimal :actual_value, precision: 10, scale: 2, default: 0.0
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 1, null: false
      t.date :due_date, null: false
      t.timestamp :completed_at
      t.boolean :deleted_at, default: false

      t.timestamps
    end
    
    add_index :goals, [:employee_id, :status] 
    add_index :goals, [:due_date, :status]
    add_index :goals, :priority
  end
end
