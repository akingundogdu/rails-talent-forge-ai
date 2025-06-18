class CreatePerformanceReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :performance_reviews do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.references :reviewer, null: false, foreign_key: { to_table: :employees }, index: true
      t.integer :status, default: 0, null: false
      t.integer :review_type, default: 0, null: false
      t.string :title, null: false
      t.text :description
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.timestamp :completed_at
      t.datetime :deleted_at, default: nil

      t.timestamps
    end
    
    add_index :performance_reviews, [:employee_id, :review_type]
    add_index :performance_reviews, [:status, :start_date]
    add_index :performance_reviews, :completed_at
  end
end
