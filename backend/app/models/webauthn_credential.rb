# A passkey (WebAuthn credential) of a console user or an end user. Only its public key is stored.
# It belongs to one domain (`rp_id`): the console's host, or a project's custom domain.
class WebauthnCredential < ApplicationRecord
  include HasUid

  self.uid_prefix = "pk"

  MAX_PER_USER = 20

  belongs_to :subject, polymorphic: true

  validates :name, presence: true, length: { maximum: 60 }
  validates :external_id, :public_key, :rp_id, presence: true
  validate :within_user_limit, on: :create

  # @return [Array<String>] what signing in with it proves: the key's kind, and that the user unlocked it
  def amr
    [ backup_eligible ? Auth::Amr::SOFTWARE_KEY : Auth::Amr::HARDWARE_KEY, Auth::Amr::USER_VERIFIED ]
  end

  private

  def within_user_limit
    return if subject.nil? || WebauthnCredential.where(subject: subject).count < MAX_PER_USER

    errors.add(:base, "A user can have at most #{MAX_PER_USER} passkeys")
  end
end
