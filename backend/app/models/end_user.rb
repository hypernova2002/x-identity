# A user in a project's directory, signing in to the project's own apps through app clients.
# Invited users have no password until they accept their invitation.
class EndUser < ApplicationRecord
  include HasUid
  include Authenticatable
  include HasLocale

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
    %w[uid email name status]
  end

  def self.ransackable_scopes(_auth_object = nil)
    %w[with_verified_email with_mfa invitation_pending in_group]
  end

  # Ransack doesn't call a scope given `false`, so these take the request's "true" or "false" as is.
  def self.ransackable_scopes_skip_sanitize_args
    %w[with_verified_email with_mfa]
  end

  FLAGS = { "true" => true, "false" => false }.freeze

  scope :with_verified_email, lambda { |verified|
    case FLAGS[verified.to_s]
    when true then where.not(email_verified_at: nil)
    when false then where(email_verified_at: nil)
    else all
    end
  }
  # The credential and identity checks are correlated EXISTS subqueries, so each end user only looks
  # at its own rows instead of every project's.
  scope :with_mfa, lambda { |enabled|
    credential = OtpCredential.confirmed.where(subject_type: "EndUser").where(OtpCredential.arel_table[:subject_id].eq(arel_table[:id])).select(1).arel.exists
    case FLAGS[enabled.to_s]
    when true then where(credential)
    when false then where(credential.not)
    else all
    end
  }
  # Created by an admin or invited, and hasn't set a password or linked a provider yet.
  scope :invitation_pending, lambda {
    identity = EndUserIdentity.where(EndUserIdentity.arel_table[:end_user_id].eq(arel_table[:id])).select(1).arel.exists
    where(password_digest: nil).where(identity.not)
  }
  scope :in_group, ->(group_uid) { where(id: GroupMembership.joins(:group).where(groups: { uid: group_uid }).select(:end_user_id)) }

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
    errors.add(:custom_attributes, :not_an_object) unless custom_attributes.is_a?(Hash)
  end
end
