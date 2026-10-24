class AddNotifyNewDevicesToAuthConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_configurations, :notify_new_devices, :boolean, null: false, default: true
  end
end
