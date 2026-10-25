# A custom domain a project's hosted login and endpoints can be served on, e.g. login.acme.com.
# The owner proves control with a TXT record and points it at x-identity with a CNAME; see
# {Domains::Verification}. A project has at most one verified domain and one being set up.
class ProjectDomain < ApplicationRecord
  include HasUid

  self.uid_prefix = "dom"

  # Pending domains are checked for this long before they're marked failed.
  VERIFY_FOR = 72.hours
  TXT_RECORD_PREFIX = "_x-identity"
  HOSTNAME_FORMAT = /\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

  belongs_to :project

  enum :status, { pending: "pending", verified: "verified", failed: "failed" }, prefix: true, validate: true

  normalizes :hostname, with: ->(hostname) { hostname.strip.downcase.chomp(".") }

  before_validation :set_defaults, on: :create

  validates :hostname, presence: true, format: { with: HOSTNAME_FORMAT, message: "must be a hostname like login.example.com" },
    uniqueness: { message: "is already used by a project" }
  validate :hostname_allowed

  # @return [String] the TXT record that proves the project's owner controls the domain
  def txt_record_name
    "#{TXT_RECORD_PREFIX}.#{hostname}"
  end

  # @return [String] what the domain's CNAME record must point at
  def cname_target
    Rails.configuration.x.custom_domain_target
  end

  # @return [Time] when a pending domain stops being checked and is marked failed
  def verify_until
    created_at + VERIFY_FOR
  end

  # @return [Boolean] a *.localhost domain, which verifies without DNS outside production
  def local?
    hostname.end_with?(".localhost")
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.verification_token ||= SecureRandom.hex(20)
    self.certificate_status ||= Domains::Certificates.status_for(self)
  end

  def hostname_allowed
    return if hostname.blank?

    errors.add(:hostname, "can't be a .localhost domain in production") if local? && Rails.env.production?
    reserved = [ Rails.configuration.x.app_base_url, Rails.configuration.x.console_base_url ].map { |url| URI.parse(url).host } + [ cname_target ]
    # Subdomains of x-identity's own hosts are reserved too, except in development, where they're all on localhost.
    errors.add(:hostname, "belongs to x-identity") if reserved.any? { |host| hostname == host || (host != "localhost" && hostname.end_with?(".#{host}")) }
  end
end
