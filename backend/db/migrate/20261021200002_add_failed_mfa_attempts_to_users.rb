class AddFailedMfaAttemptsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_mfa_attempts, :integer, null: false, default: 0
    add_column :end_users, :failed_mfa_attempts, :integer, null: false, default: 0
  end
end
