class Account < ApplicationRecord
  include HasUid

  self.uid_prefix = "acct"

  RESERVED_SLUGS = %w[
    sign-in sign-up console admin api app auth help login logout settings support www
  ].freeze

  has_many :users
  # Deleted projects are left out everywhere, until they're restored or purged.
  has_many :projects, -> { where(deleted_at: nil) }
  has_many :deleted_projects, -> { where.not(deleted_at: nil) }, class_name: "Project"
  has_many :invitations
  has_many :audit_events
  has_many :signing_keys, as: :owner
  has_one :auth_configuration, as: :owner

  normalizes :slug, with: ->(slug) { slug.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug,
    presence: true,
    length: { in: 3..40 },
    format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/, message: "may only contain lowercase letters, numbers and hyphens" },
    exclusion: { in: RESERVED_SLUGS, message: "is reserved" },
    uniqueness: true

  # @return [Realms::AccountRealm]
  def realm
    Realms::AccountRealm.new(self)
  end

  # The account's auth configuration, created with defaults if it doesn't exist yet.
  # @return [AuthConfiguration]
  def auth_configuration!
    auth_configuration || create_auth_configuration!
  end

  # The `iss` claim for tokens issued to this account's users.
  # @return [String]
  def token_issuer
    "#{Rails.configuration.x.app_base_url}/v1/accounts/#{uid}"
  end
end
