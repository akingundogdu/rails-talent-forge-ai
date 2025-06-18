class AddMeasurementPeriodToKpis < ActiveRecord::Migration[7.1]
  def change
    add_column :kpis, :measurement_period, :string
  end
end
