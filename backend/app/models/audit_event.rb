# An append-only record of a security-relevant action. Actor and target are stored as uid/label
# snapshots so events stay readable after the records they describe are deleted.
class AuditEvent < ApplicationRecord
  include HasUid

  self.uid_prefix = "evt"

  belongs_to :account
  belongs_to :project, optional: true

  validates :action, presence: true, length: { maximum: 100 }
  validates :actor_type, presence: true
  validates :occurred_at, presence: true

  def readonly?
    persisted?
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[action actor_uid target_uid app_client_uid saml_app_uid occurred_at]
  end
end
