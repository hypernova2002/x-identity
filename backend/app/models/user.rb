# A console user: belongs to one account and administers it.
class User < ApplicationRecord
  include HasUid
  include Authenticatable
  include HasLocale

  self.uid_prefix = "usr"

  belongs_to :account
  has_many :project_memberships, dependent: :delete_all
  has_many :projects, through: :project_memberships

  enum :role, { owner: "owner", admin: "admin", member: "member" }, validate: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[name email role status]
  end

  validates :name, presence: true, length: { maximum: 100 }
  validates :email,
    presence: true,
    length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { scope: :account_id }
  validates :password_digest, presence: true
  validates :password_changed_at, presence: true

  # @return [Realms::AccountRealm]
  def realm
    Realms::AccountRealm.new(account)
  end

  # @return [Boolean] whether the user can manage the account (owners and admins)
  def account_admin?
    owner? || admin?
  end
end
