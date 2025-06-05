class CreateDepartments < ActiveRecord::Migration[7.0]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.text :description
      t.references :parent_department, null: true
      t.references :manager, null: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :departments, :name
    add_index :departments, :deleted_at
  end

  def up
    execute <<-SQL
      ALTER TABLE departments
        ADD CONSTRAINT fk_departments_parent
        FOREIGN KEY (parent_department_id)
        REFERENCES departments(id)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE departments
        DROP CONSTRAINT IF EXISTS fk_departments_parent
    SQL
  end
end 