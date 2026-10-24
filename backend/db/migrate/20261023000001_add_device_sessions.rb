class AddDeviceSessions < ActiveRecord::Migration[8.1]
  # Plain classes so the backfill doesn't depend on the app's models as they change later.
  class MigrationDeviceSession < ActiveRecord::Base
    self.table_name = "device_sessions"
  end

  class MigrationRefreshToken < ActiveRecord::Base
    self.table_name = "refresh_tokens"
  end

  class MigrationBrowserSession < ActiveRecord::Base
    self.table_name = "browser_sessions"
  end

  def up
    create_table :device_sessions do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :subject, polymorphic: true, null: false
      t.references :project, foreign_key: { on_delete: :cascade }
      t.string :created_ip
      t.string :created_user_agent
      t.string :last_ip
      t.string :last_user_agent
      t.string :device_name
      t.string :device_type
      t.string :city
      t.string :region
      t.string :country_code
      t.jsonb :amr, null: false, default: []
      t.datetime :authenticated_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_reference :refresh_tokens, :device_session, foreign_key: { on_delete: :nullify }
    add_reference :browser_sessions, :device_session, foreign_key: { on_delete: :nullify }

    backfill_refresh_token_families
    backfill_browser_sessions
  end

  def down
    remove_reference :browser_sessions, :device_session, foreign_key: true
    remove_reference :refresh_tokens, :device_session, foreign_key: true
    drop_table :device_sessions
  end

  private

  # Signed-in devices from before sessions were tracked have no device details, but can still be
  # listed and signed out.
  def backfill_refresh_token_families
    active = MigrationRefreshToken.where(used_at: nil, revoked_at: nil).where("expires_at > ?", Time.current)
    active.find_each do |token|
      session = create_session(token.subject_type, token.subject_id, token.amr, token.authenticated_at, token.created_at)
      MigrationRefreshToken.where(family_id: token.family_id).update_all(device_session_id: session.id)
    end
  end

  def backfill_browser_sessions
    MigrationBrowserSession.where(revoked_at: nil).where("expires_at > ?", Time.current).find_each do |browser_session|
      session = create_session("EndUser", browser_session.end_user_id, browser_session.amr, browser_session.authenticated_at,
        browser_session.last_used_at || browser_session.created_at, project_id: browser_session.project_id)
      browser_session.update_columns(device_session_id: session.id)
    end
  end

  def create_session(subject_type, subject_id, amr, authenticated_at, last_seen_at, project_id: nil)
    project_id ||= select_value("SELECT project_id FROM end_users WHERE id = #{Integer(subject_id)}") if subject_type == "EndUser"
    MigrationDeviceSession.create!(
      uid: "ses_#{SecureRandom.base58(24)}", subject_type: subject_type, subject_id: subject_id, project_id: project_id,
      amr: amr, authenticated_at: authenticated_at, last_seen_at: last_seen_at
    )
  end
end
