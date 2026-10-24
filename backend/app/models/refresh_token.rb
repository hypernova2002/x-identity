# One link in a rotating chain of refresh tokens. All tokens issued from one sign-in share a `family_id`.
class RefreshToken < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :device_session, optional: true

  validates :token_digest, presence: true, uniqueness: true
  validates :family_id, :authenticated_at, :expires_at, presence: true

  scope :active, -> { where(used_at: nil, revoked_at: nil).where("expires_at > ?", Time.current) }

  # @param token [String]
  # @return [String]
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # @param token [String]
  # @return [RefreshToken, nil]
  def self.find_by_token(token)
    find_by(token_digest: digest(token))
  end

  # @param family_id [String]
  def self.revoke_family!(family_id)
    where(family_id: family_id, revoked_at: nil).update_all(revoked_at: Time.current)
  end

  def used?
    used_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def mark_used!
    update!(used_at: Time.current)
  end
end
