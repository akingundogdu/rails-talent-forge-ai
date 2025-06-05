class AddSecurityFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :unlock_token, :string
    add_column :users, :locked_at, :datetime
    add_column :users, :last_activity_at, :datetime
    add_column :users, :encrypted_password_changed_at, :datetime

    add_index :users, :unlock_token, unique: true
    add_index :users, :last_activity_at
  end
end
