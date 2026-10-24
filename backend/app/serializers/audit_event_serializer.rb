class AuditEventSerializer
  include Alba::Resource

  attributes :uid, :action, :app_client_uid, :saml_app_uid, :ip, :user_agent, :metadata, :occurred_at

  attribute(:actor) { |event| { type: event.actor_type, uid: event.actor_uid, label: event.actor_label } }
  attribute(:target) do |event|
    event.target_type && { type: event.target_type, uid: event.target_uid, label: event.target_label }
  end
  attribute(:project_uid) { |event| event.project&.uid }
end
