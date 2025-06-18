class CreateFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :feedbacks do |t|
      t.references :giver, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :receiver, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :performance_review, null: true, foreign_key: true, index: true
      t.integer :feedback_type, default: 0, null: false
      t.text :message, null: false
      t.integer :rating, null: true
      t.boolean :anonymous, default: false
      t.datetime :deleted_at, default: nil

      t.timestamps
    end
    
    add_index :feedbacks, [:receiver_id, :feedback_type]
    add_index :feedbacks, [:giver_id, :created_at]
    add_index :feedbacks, [:performance_review_id, :feedback_type]
  end
end
