class AddPasswordlessAfterPasskey < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_configurations, :passwordless_after_passkey, :boolean, null: false, default: false
    # Until when a user who reset their password by email may sign in with it to add a new passkey.
    add_column :users, :passkey_recovery_until, :datetime
    add_column :end_users, :passkey_recovery_until, :datetime
  end
end
