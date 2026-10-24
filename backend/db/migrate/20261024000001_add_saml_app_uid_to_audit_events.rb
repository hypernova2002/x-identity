class AddSamlAppUidToAuditEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :audit_events, :saml_app_uid, :string

    # Earlier SAML sign-ins and refusals kept the app only in their metadata.
    execute <<~SQL
      UPDATE audit_events SET saml_app_uid = metadata->>'saml_app'
      WHERE action = 'end_user.signed_in_to_app' AND metadata ? 'saml_app'
    SQL
    execute <<~SQL
      UPDATE audit_events SET saml_app_uid = metadata->>'app'
      WHERE action = 'end_user.app_access_denied' AND metadata->>'app' LIKE 'saml\\_%'
    SQL
  end

  def down
    remove_column :audit_events, :saml_app_uid
  end
end
