class AddTimeZoneToEvents < ActiveRecord::Migration
  def change
    add_column :events, :time_zone, :string, default: 'UTC'
  end
end
