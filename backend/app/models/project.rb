class Project < ApplicationRecord
  include HasUid

  self.uid_prefix = "proj"

  EMAIL_LINK_URL_FIELDS = %i[confirm_sign_up_url reset_password_url accept_invitation_url].freeze

  belongs_to :account
  has_many :project_memberships, dependent: :delete_all
  has_many :members, through: :project_memberships, source: :user
  has_many :end_users
  has_many :app_clients
  has_many :identity_providers
  has_many :groups
  has_many :saml_apps
  has_many :saml_certificates
  has_many :app_assignments
  has_many :end_user_attribute_definitions
  has_many :signing_keys, as: :owner
  has_one :auth_configuration, as: :owner

  validates :name, presence: true, length: { maximum: 100 }
  validates :allow_self_sign_up, inclusion: { in: [ true, false ] }
  validate :email_link_urls_are_templates

  def self.ransackable_attributes(_auth_object = nil)
    %w[uid name created_at]
  end

  # @return [Realms::ProjectRealm]
  def realm
    Realms::ProjectRealm.new(self)
  end

  # The project's auth configuration, created with end-user defaults if it doesn't exist yet.
  # @return [AuthConfiguration]
  def auth_configuration!
    auth_configuration || create_auth_configuration!(require_email_verification: true)
  end

  # The app portal's own OpenID Connect client, created on first use.
  # @return [AppClient]
  def portal_client!
    app_clients.find_by(system_kind: AppClient::PORTAL) ||
      app_clients.create!(name: "App portal", client_type: "public", system_kind: AppClient::PORTAL)
  rescue ActiveRecord::RecordNotUnique
    app_clients.find_by!(system_kind: AppClient::PORTAL)
  end

  # The `iss` claim for tokens issued to this project's end users.
  # @return [String]
  def token_issuer
    "#{account.token_issuer}/projects/#{uid}"
  end

  # @param field [Symbol] one of {EMAIL_LINK_URL_FIELDS}
  # @param token [String]
  # @return [String, nil] the link for an email, or nil when the project hasn't configured one
  def email_link(field, token)
    template = public_send(field)
    template.presence&.gsub("{token}", CGI.escape(token))
  end

  private

  def email_link_urls_are_templates
    EMAIL_LINK_URL_FIELDS.each do |field|
      url = public_send(field)
      next if url.blank?

      uri = URI.parse(url.gsub("{token}", "token"))
      valid_scheme = uri.scheme == "https" || (uri.scheme == "http" && %w[localhost 127.0.0.1].include?(uri.host))
      errors.add(field, "must be an https URL") unless valid_scheme && uri.host.present?
      errors.add(field, "must contain {token}") unless url.include?("{token}")
      errors.add(field, "is too long") if url.length > 2048
    rescue URI::InvalidURIError
      errors.add(field, "is not a valid URL")
    end
  end
end
