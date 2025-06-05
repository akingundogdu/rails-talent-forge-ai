class CreatePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :resource, null: false
      t.string :action, null: false
      t.bigint :resource_id
      t.timestamps
    end

    add_index :permissions, [:user_id, :resource, :action, :resource_id], unique: true, name: 'index_permissions_on_user_resource_action'
    add_index :permissions, [:resource, :resource_id]
  end
end 