# A user in a project's directory, signing in to the project's own apps through app clients.
# Invited users have no password until they accept their invitation.
class EndUser < ApplicationRecord
  include HasUid
  include Authenticatable

  self.uid_prefix = "eu"

  belongs_to :project
  has_many :identities, class_name: "EndUserIdentity", dependent: :delete_all
  has_many :browser_sessions, dependent: :destroy
  has_many :group_memberships, dependent: :delete_all
  has_many :groups, through: :group_memberships
  has_many :app_assignments, as: :principal, dependent: :delete_all

  validates :email,
    presence: true,
    length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { scope: :project_id }
  validates :name, length: { maximum: 100 }, allow_nil: true
  validate :custom_attributes_is_a_hash

  after_create :join_default_groups

  def self.ransackable_attributes(_auth_object = nil)
    %w[email name status]
  end

  # @return [Realms::ProjectRealm]
  def realm
    Realms::ProjectRealm.new(project)
  end

  # @return [Boolean]
  def password_set?
    password_digest.present?
  end

  private

  # However they were created (sign-up, an admin, an invitation or an identity provider).
  def join_default_groups
    project.groups.for_new_users.find_each { |group| group_memberships.create!(group: group) }
  end

  def custom_attributes_is_a_hash
    errors.add(:custom_attributes, "must be an object") unless custom_attributes.is_a?(Hash)
  end
end
