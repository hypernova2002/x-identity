class AddOnCustomDomainToSamlConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :saml_apps, :on_custom_domain, :boolean, null: false, default: false
    add_column :identity_providers, :on_custom_domain, :boolean, null: false, default: false
  end
end
