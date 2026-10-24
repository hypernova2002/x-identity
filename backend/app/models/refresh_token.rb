# One link in a rotating chain of refresh tokens. All tokens issued from one sign-in share a `family_id`.
class RefreshToken < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :device_session, optional: true

  # Tokens are 43 random base58 characters; the unique index guards against collisions without a
  # query before every refresh.
  validates :token_digest, presence: true
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

  # Deletes a user's refresh tokens from sessions that have ended: expired or revoked. Used tokens
  # of live sessions stay, because presenting one again is how a stolen token is noticed.
  # @param subject [User, EndUser]
  def self.prune_for!(subject)
    Prunable.delete_batch(where(subject: subject).where("revoked_at IS NOT NULL OR expires_at < ?", Time.current))
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
