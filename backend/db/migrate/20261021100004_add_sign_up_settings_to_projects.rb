class AddSignUpSettingsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :allow_self_sign_up, :boolean, null: false, default: true
    add_column :projects, :confirm_sign_up_url, :string
    add_column :projects, :reset_password_url, :string
    add_column :projects, :accept_invitation_url, :string
  end
end
