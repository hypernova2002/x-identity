# One of a confidential client's secrets. Only a digest is stored. Rotating keeps the previous
# secret working for the project's rotation overlap, so services can switch over without downtime.
class AppClientSecret < ApplicationRecord
  include HasUid

  self.uid_prefix = "sec"

  # Last use is recorded at most this often, so busy services don't write on every request.
  USE_INTERVAL = 1.minute

  belongs_to :app_client

  scope :usable, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # @param secret [String]
  # @return [String]
  def self.digest(secret)
    OpenSSL::Digest::SHA256.hexdigest(secret.to_s)
  end

  # @param app_client [AppClient]
  # @return [Array(AppClientSecret, String)] the record and the secret, which can't be read again
  def self.issue!(app_client)
    secret = SecureRandom.base58(48)
    [ create!(app_client: app_client, digest: digest(secret), last_four: secret.last(4)), secret ]
  end

  def record_use!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < USE_INTERVAL.ago
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at
  end
end
