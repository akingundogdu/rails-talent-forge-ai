module UserActivity
  extend ActiveSupport::Concern

  included do
    before_action :update_user_activity
  end

  private

  def update_user_activity
    return unless current_user
    
    current_user.update_column(
      :last_activity_at, 
      Time.current
    ) if should_update_activity?
  end

  def should_update_activity?
    current_user.last_activity_at.nil? ||
      current_user.last_activity_at < 5.minutes.ago
  end
end 