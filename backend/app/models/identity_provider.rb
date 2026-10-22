# A social, OpenID Connect or SAML provider end users of a project can sign in with. Google and
# Apple have fixed endpoints; generic OIDC providers are configured from their discovery document,
# whose endpoints are stored in `metadata` when the provider is saved. SAML providers are a
# customer's own identity provider, with the project as the service provider; they're trusted for
# the email domains they list, which also route users to them on the hosted login page.
class IdentityProvider < ApplicationRecord
  include HasUid

  self.uid_prefix = "idp"

  MAX_AUDIENCES = 10
  METADATA_KEYS = %w[issuer authorization_endpoint token_endpoint jwks_uri].freeze
  APPLE_ID_FORMAT = /\A[A-Z0-9]{10}\z/
  SCOPE_FORMAT = /\A[\x21\x23-\x5B\x5D-\x7E]+( [\x21\x23-\x5B\x5D-\x7E]+)*\z/
  APPLE_SCOPES = "name email".freeze
  DOMAIN_FORMAT = /\A(?=.{1,253}\z)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/
  MAX_DOMAINS = 50
  MAX_CERTIFICATES = 5

  # Google issues tokens with either issuer.
  GOOGLE_ISSUERS = %w[https://accounts.google.com accounts.google.com].freeze

  PRESETS = {
    "google" => {
      "issuer" => "https://accounts.google.com",
      "authorization_endpoint" => "https://accounts.google.com/o/oauth2/v2/auth",
      "token_endpoint" => "https://oauth2.googleapis.com/token",
      "jwks_uri" => "https://www.googleapis.com/oauth2/v3/certs",
      "code_challenge_methods_supported" => [ "S256" ]
    },
    "apple" => {
      "issuer" => "https://appleid.apple.com",
      "authorization_endpoint" => "https://appleid.apple.com/auth/authorize",
      "token_endpoint" => "https://appleid.apple.com/auth/token",
      "jwks_uri" => "https://appleid.apple.com/auth/keys"
    }
  }.freeze

  belongs_to :project
  has_many :identities, class_name: "EndUserIdentity", dependent: :delete_all
  has_many :group_mappings, class_name: "IdentityProviderGroupMapping", dependent: :delete_all
  has_many :consumed_saml_assertions, dependent: :delete_all

  enum :kind, { google: "google", apple: "apple", oidc: "oidc", saml: "saml" }, validate: true, prefix: true

  encrypts :client_secret, :apple_private_key

  attr_readonly :kind

  validates :name, presence: true, length: { maximum: 100 }
  validates :client_id, presence: true, length: { maximum: 255 }, unless: :kind_saml?
  validates :scopes, length: { maximum: 500 }, format: { with: SCOPE_FORMAT, message: "must be scopes separated by single spaces" }
  validates :client_secret, presence: true, length: { maximum: 1000 }, if: -> { kind_google? || kind_oidc? }
  validates :saml_idp_entity_id, presence: true, length: { maximum: 1024 }, if: :kind_saml?
  validates :saml_name_id_format, inclusion: { in: SamlApp::NAME_ID_FORMATS.keys }
  validates :saml_email_attribute, :saml_name_attribute, :saml_groups_attribute, length: { maximum: 255 }, allow_nil: true
  validate :saml_urls_are_web_urls, if: :kind_saml?
  validate :saml_certificates_are_certificates, if: :kind_saml?
  validate :domains_are_unique_domains
  validates :discovery_url, presence: true, length: { maximum: 2048 }, if: :kind_oidc?
  validates :apple_team_id, :apple_key_id, format: { with: APPLE_ID_FORMAT, message: "must be 10 letters and digits" }, if: :kind_apple?
  validate :scopes_include_openid, if: -> { kind_google? || kind_oidc? }
  validate :additional_audiences_are_strings
  validate :apple_private_key_is_an_ec_key, if: :kind_apple?
  validate :metadata_is_complete, if: :kind_oidc?

  scope :enabled, -> { where(enabled: true) }

  normalizes :domains, with: ->(domains) { Array(domains).map { |domain| domain.to_s.strip.downcase.delete_prefix("@") }.compact_blank.uniq }

  # @return [Hash{String => Object}] issuer, authorization_endpoint, token_endpoint and jwks_uri
  def endpoints
    PRESETS.fetch(kind) { metadata }
  end

  # @return [Array<String>] the `iss` values the provider's ID tokens may carry
  def issuers
    kind_google? ? GOOGLE_ISSUERS : [ endpoints["issuer"] ]
  end

  # The provider client id, plus the ids of native apps that send the provider's ID tokens directly.
  # @return [Array<String>]
  def audiences
    [ client_id, *additional_audiences ]
  end

  # @return [String] Apple ignores `openid` and only accepts these scopes
  def requested_scopes
    kind_apple? ? APPLE_SCOPES : scopes
  end

  # @return [Boolean] whether the provider accepts PKCE on its authorization endpoint
  def supports_pkce?
    Array(endpoints["code_challenge_methods_supported"]).include?("S256")
  end

  # Where the provider sends users back to after they sign in. Admins register it with the provider.
  # @return [String]
  def callback_url
    "#{project.token_issuer}/auth/providers/callback"
  end

  # @return [String] the SAML service provider's entity ID, which is also its metadata URL
  def sp_entity_id
    "#{sp_base_url}/metadata"
  end

  def acs_url
    "#{sp_base_url}/acs"
  end

  def sp_slo_url
    "#{sp_base_url}/slo"
  end

  # @param email [String, nil]
  # @return [Boolean] whether the email is in one of the provider's domains
  def authoritative_for?(email)
    domain = email.to_s.split("@", 2).last.to_s.downcase
    email.to_s.include?("@") && domains.include?(domain)
  end

  # @return [Array<OpenSSL::X509::Certificate>]
  def saml_x509_certificates
    Array(saml_idp_certificates).filter_map do |pem|
      OpenSSL::X509::Certificate.new(pem)
    rescue OpenSSL::X509::CertificateError
      nil
    end
  end

  # @return [OpenSSL::PKey::EC, nil]
  def apple_signing_key
    return nil if apple_private_key.blank?

    key = OpenSSL::PKey.read(apple_private_key)
    key.is_a?(OpenSSL::PKey::EC) ? key : nil
  rescue OpenSSL::PKey::PKeyError
    nil
  end

  private

  def sp_base_url
    "#{project.token_issuer}/saml/sp/#{uid}"
  end

  def saml_urls_are_web_urls
    errors.add(:saml_sso_url, "must be an https URL (or http://localhost)") unless WebUrl.valid?(saml_sso_url)
    errors.add(:saml_slo_url, "must be an https URL (or http://localhost)") if saml_slo_url.present? && !WebUrl.valid?(saml_slo_url)
  end

  def saml_certificates_are_certificates
    certificates = Array(saml_idp_certificates)
    valid = certificates.size.between?(1, MAX_CERTIFICATES) && saml_x509_certificates.size == certificates.size
    errors.add(:saml_idp_certificates, "must be 1 to #{MAX_CERTIFICATES} X.509 certificates in PEM format") unless valid
  end

  def domains_are_unique_domains
    unless domains.is_a?(Array) && domains.size <= MAX_DOMAINS && domains.all? { |domain| domain.match?(DOMAIN_FORMAT) }
      return errors.add(:domains, "must be up to #{MAX_DOMAINS} domains like acme.com")
    end

    taken = project&.identity_providers&.where.not(id: id)&.flat_map(&:domains).to_a & domains
    errors.add(:domains, "already belong to another provider: #{taken.join(', ')}") if taken.any?
  end

  def scopes_include_openid
    errors.add(:scopes, "must include openid") unless scopes.to_s.split(" ").include?("openid")
  end

  def additional_audiences_are_strings
    valid = additional_audiences.is_a?(Array) && additional_audiences.size <= MAX_AUDIENCES &&
      additional_audiences.all? { |audience| audience.is_a?(String) && audience.present? && audience.length <= 255 }
    errors.add(:additional_audiences, "must be a list of at most #{MAX_AUDIENCES} client ids") unless valid
  end

  def apple_private_key_is_an_ec_key
    errors.add(:apple_private_key, "must be the .p8 key from Apple, in PEM format") unless apple_signing_key
  end

  def metadata_is_complete
    missing = METADATA_KEYS.reject { |key| metadata.is_a?(Hash) && metadata[key].present? }
    errors.add(:discovery_url, "hasn't been loaded, or is missing #{missing.join(', ')}") if missing.any?
  end
end
