class AddDeletedAtToFeedbackRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :feedback_requests, :deleted_at, :datetime
  end
end
