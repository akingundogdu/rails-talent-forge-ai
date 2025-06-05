class CreateEmployees < ActiveRecord::Migration[7.0]
  def change
    create_table :employees do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.references :position, null: false
      t.references :manager, null: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :employees, :email, unique: true
    add_index :employees, :deleted_at
    add_index :employees, [:first_name, :last_name]

    add_foreign_key :employees, :positions
    add_foreign_key :departments, :employees, column: :manager_id
  end

  def up
    execute <<-SQL
      ALTER TABLE employees
        ADD CONSTRAINT fk_employees_manager
        FOREIGN KEY (manager_id)
        REFERENCES employees(id)
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE employees
        DROP CONSTRAINT IF EXISTS fk_employees_manager
    SQL
  end
end 