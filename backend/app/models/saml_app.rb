# A service provider (app) that signs a project's end users in with SAML 2.0, using the project as
# its identity provider.
class SamlApp < ApplicationRecord
  include HasUid
  include OnCustomDomain

  self.uid_prefix = "saml"

  NAME_ID_FORMATS = {
    "email" => "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
    "persistent" => "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent",
    "unspecified" => "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
  }.freeze
  ATTRIBUTE_SOURCES = %w[email email_verified name uid groups].freeze
  CUSTOM_ATTRIBUTE_SOURCE = /\Acustom:[a-z][a-z0-9_]{0,#{EndUserAttributeDefinition::KEY_MAX_LENGTH - 1}}\z/
  MAX_ACS_URLS = 10
  MAX_ATTRIBUTES = 20

  belongs_to :project
  has_many :app_assignments, as: :app, dependent: :delete_all
  has_many :browser_session_apps, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }
  validates :entity_id, presence: true, length: { maximum: 1024 }, uniqueness: { scope: :project_id }
  validates :name_id_format, inclusion: { in: NAME_ID_FORMATS.keys }
  validates :default_relay_state, length: { maximum: 1024 }, allow_nil: true
  validate :acs_urls_are_web_urls
  validate :slo_url_is_a_web_url
  validate :sp_certificate_is_a_certificate
  validate :attribute_mappings_are_valid
  validate :signed_requests_need_a_certificate

  scope :enabled, -> { where(enabled: true) }

  # @return [String]
  def name_id_format_uri
    NAME_ID_FORMATS.fetch(name_id_format)
  end

  # @param url [String, nil]
  # @return [Boolean] whether the URL is one of the app's assertion consumer service URLs
  def acs_url_allowed?(url)
    url.present? && acs_urls.include?(url)
  end

  # @return [String] where unsolicited (IdP-initiated) responses go
  def default_acs_url
    acs_urls.first
  end

  # @return [OpenSSL::X509::Certificate, nil] the app's certificate, for its signed requests
  def certificate
    sp_certificate.present? ? OpenSSL::X509::Certificate.new(sp_certificate) : nil
  rescue OpenSSL::X509::CertificateError
    nil
  end

  # @return [String] starts an IdP-initiated sign-in, e.g. from the app portal
  def launch_url
    project_endpoints.url("/saml/apps/#{uid}/launch")
  end

  private

  def acs_urls_are_web_urls
    valid = acs_urls.is_a?(Array) && acs_urls.size.between?(1, MAX_ACS_URLS) && acs_urls.all? { |url| WebUrl.valid?(url) }
    errors.add(:acs_urls, "must be 1 to #{MAX_ACS_URLS} https URLs (or http://localhost)") unless valid
  end

  def slo_url_is_a_web_url
    errors.add(:slo_url, "must be an https URL (or http://localhost)") if slo_url.present? && !WebUrl.valid?(slo_url)
  end

  def sp_certificate_is_a_certificate
    errors.add(:sp_certificate, "must be an X.509 certificate in PEM format") if sp_certificate.present? && certificate.nil?
  end

  def attribute_mappings_are_valid
    valid = attribute_mappings.is_a?(Array) && attribute_mappings.size <= MAX_ATTRIBUTES && attribute_mappings.all? do |mapping|
      mapping.is_a?(Hash) && mapping.keys.sort == %w[name source] &&
        mapping["name"].is_a?(String) && mapping["name"].present? && mapping["name"].length <= 255 &&
        (ATTRIBUTE_SOURCES.include?(mapping["source"]) || mapping["source"].to_s.match?(CUSTOM_ATTRIBUTE_SOURCE))
    end
    names = Array(attribute_mappings).filter_map { |mapping| mapping["name"] if mapping.is_a?(Hash) }
    valid &&= names.uniq.size == names.size
    unless valid
      errors.add(:attribute_mappings, "must be up to #{MAX_ATTRIBUTES} attributes with unique names, each from " \
        "#{ATTRIBUTE_SOURCES.join(', ')} or custom:<attribute key>")
    end
  end

  def signed_requests_need_a_certificate
    errors.add(:require_signed_requests, "needs the app's certificate") if require_signed_requests && sp_certificate.blank?
  end
end
