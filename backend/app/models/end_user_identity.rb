# Links an end user to their account at an identity provider, identified by the provider's `sub`.
class EndUserIdentity < ApplicationRecord
  include HasUid

  self.uid_prefix = "eui"

  belongs_to :end_user
  belongs_to :identity_provider

  validates :subject, presence: true, length: { maximum: 255 }, uniqueness: { scope: :identity_provider_id }
  validates :identity_provider_id, uniqueness: { scope: :end_user_id }
end
