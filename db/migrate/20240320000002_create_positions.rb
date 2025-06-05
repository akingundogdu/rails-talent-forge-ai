class CreatePositions < ActiveRecord::Migration[7.0]
  def change
    create_table :positions do |t|
      t.string :title, null: false
      t.text :description
      t.integer :level, null: false
      t.references :department, null: false
      t.references :parent_position, null: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :positions, :title
    add_index :positions, :level
    add_index :positions, :deleted_at

    add_foreign_key :positions, :departments
  end

  def up
    execute <<-SQL
      ALTER TABLE positions
        ADD CONSTRAINT fk_positions_parent
        FOREIGN KEY (parent_position_id)
        REFERENCES positions(id)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE positions
        DROP CONSTRAINT IF EXISTS fk_positions_parent
    SQL
  end
end 