# An application that signs end users in to a project. Its uid is the public `client_id`.
# Confidential clients (server-side apps) also hold a secret; public clients (browsers, mobile) don't.
class AppClient < ApplicationRecord
  include HasUid

  self.uid_prefix = "cl"

  ORIGIN_FORMAT = %r{\Ahttps?://[a-z0-9.-]+(:\d{1,5})?\z}
  MAX_ORIGINS = 20

  belongs_to :project

  enum :client_type, { public: "public", confidential: "confidential" }, validate: true, prefix: true

  validates :name, presence: true, length: { maximum: 100 }
  validate :allowed_origins_are_origins

  scope :enabled, -> { where(enabled: true) }

  # @param origin [String]
  # @return [Boolean] whether any enabled app client lists the origin
  def self.allows_origin?(origin)
    origin.present? && enabled.where("allowed_origins @> ?", [ origin ].to_json).exists?
  end

  # Generates a new secret, replacing any earlier one.
  # @return [String] the plaintext secret, shown to the admin once
  def generate_secret
    secret = SecureRandom.base58(48)
    self.client_secret_digest = OpenSSL::Digest::SHA256.hexdigest(secret)
    secret
  end

  # Public clients need no secret; confidential clients must present theirs.
  # @param secret [String, nil]
  # @return [Boolean]
  def authenticate(secret)
    return true if client_type_public?
    return false if secret.blank? || client_secret_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(client_secret_digest, OpenSSL::Digest::SHA256.hexdigest(secret.to_s))
  end

  private

  def allowed_origins_are_origins
    unless allowed_origins.is_a?(Array) && allowed_origins.size <= MAX_ORIGINS
      return errors.add(:allowed_origins, "must be a list of at most #{MAX_ORIGINS} origins")
    end

    invalid = allowed_origins.reject { |origin| origin.is_a?(String) && origin.match?(ORIGIN_FORMAT) }
    errors.add(:allowed_origins, "must look like https://app.example.com, without a path: #{invalid.join(', ')}") if invalid.any?
  end
end
