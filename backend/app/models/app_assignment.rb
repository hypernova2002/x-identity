# Gives an end user, or every member of a group, access to an app: an app client or a SAML app.
class AppAssignment < ApplicationRecord
  include HasUid

  self.uid_prefix = "asg"

  belongs_to :project
  belongs_to :app, polymorphic: true
  belongs_to :principal, polymorphic: true

  validates :app_type, inclusion: { in: %w[AppClient SamlApp] }
  validates :principal_type, inclusion: { in: %w[EndUser Group] }
  validates :principal_id, uniqueness: { scope: %i[app_type app_id principal_type] }
  validate :everything_in_one_project

  # @param app [AppClient, SamlApp]
  # @param end_user [EndUser]
  # @return [Boolean] whether the user is assigned the app, directly or through a group
  def self.grants?(app, end_user)
    group_ids = GroupMembership.where(end_user_id: end_user.id).select(:group_id)
    where(app: app).where(principal: end_user).or(where(app: app, principal_type: "Group", principal_id: group_ids)).exists?
  end

  private

  def everything_in_one_project
    return if app.nil? || principal.nil?

    errors.add(:principal, :other_project) unless app.project_id == project_id && principal.project_id == project_id
  end
end
