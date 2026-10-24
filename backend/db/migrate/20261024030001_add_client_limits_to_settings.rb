class AddClientLimitsToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_configurations, :client_secret_rotation_overlap_seconds, :integer, null: false, default: 7.days.to_i
    add_column :auth_configurations, :token_requests_per_minute, :integer, null: false, default: 120
    add_column :app_clients, :token_requests_per_minute, :integer
  end
end
