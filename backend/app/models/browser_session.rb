# A signed-in browser at a project's hosted login, so the project's other apps can sign the user in
# without asking again (single sign-on). The browser holds the token in a cookie; only its digest is
# stored. Sessions end when they expire, on logout, and when the user's sessions are revoked.
class BrowserSession < ApplicationRecord
  COOKIE_NAME = "xid_sso".freeze

  belongs_to :project
  belongs_to :end_user
  # Set when the user signed in through an upstream SAML provider, for single logout there.
  belongs_to :identity_provider, optional: true
  has_many :browser_session_apps, dependent: :delete_all

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # @param token [String]
  # @return [String]
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # @param end_user [EndUser]
  # @param amr [Array<String>]
  # @param authenticated_at [Time]
  # @param upstream [Hash, nil] identity_provider_id, name_id, name_id_format and session_index from an upstream SAML provider
  # @return [Array(BrowserSession, String)] the session and the token for the cookie
  def self.start!(end_user:, amr:, authenticated_at:, upstream: nil)
    token = SecureRandom.base58(43)
    ttl = end_user.project.auth_configuration!.sso_session_ttl_seconds.seconds
    session = create!(
      project: end_user.project, end_user: end_user, token_digest: digest(token),
      amr: amr, authenticated_at: authenticated_at, expires_at: ttl.from_now, last_used_at: Time.current,
      identity_provider_id: upstream&.dig("identity_provider_id"), upstream_name_id: upstream&.dig("name_id"),
      upstream_name_id_format: upstream&.dig("name_id_format"), upstream_session_index: upstream&.dig("session_index")
    )
    [ session, token ]
  end

  # @param token [String, nil] from the cookie
  # @param project [Project]
  # @return [BrowserSession, nil] the session, if it's still valid for an active user
  def self.find_valid(token, project:)
    return nil if token.blank?

    session = active.includes(:end_user).find_by(token_digest: digest(token), project: project)
    session if session&.valid_for_user?
  end

  # @return [Boolean] false once the user is disabled or their sessions were revoked after this one started
  def valid_for_user?
    end_user.active? && (end_user.tokens_valid_after.nil? || created_at > end_user.tokens_valid_after)
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at
  end
end
