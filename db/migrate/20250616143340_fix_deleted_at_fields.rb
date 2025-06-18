class FixDeletedAtFields < ActiveRecord::Migration[7.1]
  def up
    # Remove boolean deleted_at columns and add datetime deleted_at columns
    remove_column :feedbacks, :deleted_at
    add_column :feedbacks, :deleted_at, :datetime
    add_index :feedbacks, :deleted_at
    
    remove_column :goals, :deleted_at
    add_column :goals, :deleted_at, :datetime
    add_index :goals, :deleted_at
    
    remove_column :kpis, :deleted_at
    add_column :kpis, :deleted_at, :datetime
    add_index :kpis, :deleted_at
    
    remove_column :performance_reviews, :deleted_at
    add_column :performance_reviews, :deleted_at, :datetime
    add_index :performance_reviews, :deleted_at
    
    remove_column :ratings, :deleted_at
    add_column :ratings, :deleted_at, :datetime
    add_index :ratings, :deleted_at
  end
  
  def down
    # Reverse the changes
    remove_column :feedbacks, :deleted_at
    add_column :feedbacks, :deleted_at, :boolean, default: false
    
    remove_column :goals, :deleted_at
    add_column :goals, :deleted_at, :boolean, default: false
    
    remove_column :kpis, :deleted_at
    add_column :kpis, :deleted_at, :boolean, default: false
    
    remove_column :performance_reviews, :deleted_at
    add_column :performance_reviews, :deleted_at, :boolean, default: false
    
    remove_column :ratings, :deleted_at
    add_column :ratings, :deleted_at, :boolean, default: false
  end
end
