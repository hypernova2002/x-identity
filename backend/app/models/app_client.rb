# An application that signs end users in to a project. Its uid is the public `client_id`.
# Confidential clients (server-side apps) also hold a secret; public clients (browsers, mobile) don't.
class AppClient < ApplicationRecord
  include HasUid

  self.uid_prefix = "cl"

  ORIGIN_FORMAT = %r{\Ahttps?://[a-z0-9.-]+(:\d{1,5})?\z}
  MAX_ORIGINS = 20
  MAX_REDIRECT_URIS = 20
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
  UNSAFE_SCHEMES = %w[javascript data file vbscript about blob].freeze

  belongs_to :project

  enum :client_type, { public: "public", confidential: "confidential" }, validate: true, prefix: true

  validates :name, presence: true, length: { maximum: 100 }
  validate :allowed_origins_are_origins
  validate :redirect_uris_are_valid
  validate :post_logout_redirect_uris_are_valid

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

  # @param uri [String, nil]
  # @return [Boolean] whether the uri is registered, compared exactly
  def redirect_uri_allowed?(uri)
    uri.present? && redirect_uris.include?(uri)
  end

  # @param uri [String, nil]
  # @return [Boolean] whether the uri is a registered post-logout redirect URI, compared exactly
  def post_logout_redirect_uri_allowed?(uri)
    uri.present? && post_logout_redirect_uris.include?(uri)
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

  def redirect_uris_are_valid
    validate_uri_list(:redirect_uris)
  end

  def post_logout_redirect_uris_are_valid
    validate_uri_list(:post_logout_redirect_uris)
  end

  def validate_uri_list(attribute)
    uris = public_send(attribute)
    return errors.add(attribute, "must be a list of at most #{MAX_REDIRECT_URIS} URIs") unless uris.is_a?(Array) && uris.size <= MAX_REDIRECT_URIS

    invalid = uris.reject { |uri| uri.is_a?(String) && valid_redirect_uri?(uri) }
    return if invalid.empty?

    errors.add(attribute, "must be https URLs, http://localhost URLs or app schemes like com.example.app:/callback, " \
      "without a fragment: #{invalid.join(', ')}")
  end

  # Native apps use their own scheme (RFC 8252); browsers need https, except on the loopback interface.
  def valid_redirect_uri?(value)
    return false if value.length > 2048

    uri = URI.parse(value)
    return false if uri.scheme.blank? || uri.fragment
    return uri.host.present? if uri.scheme == "https"
    return LOOPBACK_HOSTS.include?(uri.hostname) if uri.scheme == "http"

    !UNSAFE_SCHEMES.include?(uri.scheme.downcase)
  rescue URI::InvalidURIError
    false
  end
end
