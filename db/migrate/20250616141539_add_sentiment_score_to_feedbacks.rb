class AddSentimentScoreToFeedbacks < ActiveRecord::Migration[7.1]
  def change
    add_column :feedbacks, :sentiment_score, :decimal
  end
end
