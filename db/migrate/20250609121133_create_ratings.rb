class CreateRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :ratings do |t|
      t.references :performance_review, null: false, foreign_key: true, index: true
      t.string :competency_name, null: false
      t.integer :score, null: false
      t.text :comments
      t.decimal :weight, precision: 5, scale: 2, default: 1.0
      t.boolean :deleted_at, default: false

      t.timestamps
    end
    
    add_index :ratings, [:performance_review_id, :competency_name], unique: true
    add_index :ratings, :score
    
    # Score validation at database level
    add_check_constraint :ratings, "score >= 1 AND score <= 5", name: "score_range_check"
  end
end
