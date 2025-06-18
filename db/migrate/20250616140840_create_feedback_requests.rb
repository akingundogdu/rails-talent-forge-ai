class CreateFeedbackRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :feedback_requests do |t|
      t.references :requester, null: false, foreign_key: { to_table: :employees }
      t.references :recipient, null: false, foreign_key: { to_table: :employees }
      t.text :message
      t.string :feedback_type
      t.string :status, default: 'pending'

      t.timestamps
    end
  end
end
