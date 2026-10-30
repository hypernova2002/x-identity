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

  PORTAL = "portal".freeze

  belongs_to :project
  has_many :app_assignments, as: :app, dependent: :delete_all
  has_many :secrets, class_name: "AppClientSecret", dependent: :delete_all
  has_many :api_grants, dependent: :delete_all

  enum :client_type, { public: "public", confidential: "confidential" }, validate: true, prefix: true

  validates :name, presence: true, length: { maximum: 100 }
  validate :allowed_origins_are_origins
  validate :redirect_uris_are_valid
  validate :post_logout_redirect_uris_are_valid
  validates :launch_url, length: { maximum: WebUrl::MAX_LENGTH }, allow_nil: true
  validate :launch_url_is_a_web_url
  validates :system_kind, inclusion: { in: [ PORTAL ] }, allow_nil: true
  validate :machine_apps_are_confidential_and_browserless
  validates :token_requests_per_minute, numericality: { only_integer: true, in: AuthConfiguration::TOKEN_REQUESTS_PER_MINUTE }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  # Clients admins create; the system's own clients (the app portal) are managed by x-identity.
  scope :managed, -> { where(system_kind: nil) }

  # @param origin [String]
  # @return [Boolean] whether any enabled app client lists the origin
  def self.allows_origin?(origin)
    origin.present? && enabled.where("allowed_origins @> ?", [ origin ].to_json).exists?
  end

  # Generates a new secret, replacing any earlier one.
  # @return [String] the plaintext secret, shown to the admin once
  # A new secret. Older secrets keep working for the project's rotation overlap (none when it's 0),
  # unless revoked sooner.
  # @return [String] the secret, which can't be read again
  def rotate_secret!
    overlap = project.auth_configuration!.client_secret_rotation_overlap_seconds.seconds
    transaction do
      older = secrets.usable
      if overlap.zero?
        older.update_all(revoked_at: Time.current)
      else
        older.where("expires_at IS NULL OR expires_at > ?", overlap.from_now).update_all(expires_at: overlap.from_now)
      end
      AppClientSecret.issue!(self).last
    end
  end

  # @return [Integer] token endpoint requests allowed per minute
  def token_rate_limit
    token_requests_per_minute || project.auth_configuration!.token_requests_per_minute
  end

  def portal?
    system_kind == PORTAL
  end

  # @param uri [String, nil]
  # @return [Boolean] whether the uri is registered, compared exactly
  def redirect_uri_allowed?(uri)
    return ProjectEndpoints.all(project).any? { |endpoints| uri == endpoints.hosted_page("apps") } if portal?

    uri.present? && redirect_uris.include?(uri)
  end

  # @param uri [String, nil]
  # @return [Boolean] whether the uri is a registered post-logout redirect URI, compared exactly
  def post_logout_redirect_uri_allowed?(uri)
    return ProjectEndpoints.all(project).any? { |endpoints| uri == endpoints.hosted_page("signed-out") } if portal?

    uri.present? && post_logout_redirect_uris.include?(uri)
  end

  # Public clients need no secret; confidential clients must present theirs.
  # @param secret [String, nil]
  # @return [Boolean]
  # @param secret [String, nil]
  # @return [Boolean] true for public clients; for confidential ones, whether a usable secret matches
  def authenticate(secret)
    return true if client_type_public?
    return false if secret.blank?

    match = secrets.usable.find_by(digest: AppClientSecret.digest(secret))
    match&.record_use!
    match.present?
  end

  private

  def machine_apps_are_confidential_and_browserless
    return unless machine?

    errors.add(:client_type, :machine_app_not_confidential) unless client_type_confidential?
    { allowed_origins: allowed_origins, redirect_uris: redirect_uris, post_logout_redirect_uris: post_logout_redirect_uris }.each do |field, values|
      errors.add(field, :not_for_machine_apps) if values.present?
    end
    errors.add(:launch_url, :not_for_machine_apps) if launch_url.present?
  end

  def allowed_origins_are_origins
    unless allowed_origins.is_a?(Array) && allowed_origins.size <= MAX_ORIGINS
      return errors.add(:allowed_origins, :invalid_origin_list, count: MAX_ORIGINS)
    end

    invalid = allowed_origins.reject { |origin| origin.is_a?(String) && origin.match?(ORIGIN_FORMAT) }
    errors.add(:allowed_origins, :invalid_origins, origins: invalid) if invalid.any?
  end

  def launch_url_is_a_web_url
    errors.add(:launch_url, :not_web_url) if launch_url.present? && !WebUrl.valid?(launch_url)
  end

  def redirect_uris_are_valid
    validate_uri_list(:redirect_uris)
  end

  def post_logout_redirect_uris_are_valid
    validate_uri_list(:post_logout_redirect_uris)
  end

  def validate_uri_list(attribute)
    uris = public_send(attribute)
    return errors.add(attribute, :invalid_redirect_uri_list, count: MAX_REDIRECT_URIS) unless uris.is_a?(Array) && uris.size <= MAX_REDIRECT_URIS

    invalid = uris.reject { |uri| uri.is_a?(String) && valid_redirect_uri?(uri) }
    return if invalid.empty?

    errors.add(attribute, :invalid_redirect_uris, uris: invalid)
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
