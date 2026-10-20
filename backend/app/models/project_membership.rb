class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum :role, { admin: "admin", developer: "developer", viewer: "viewer" }, validate: true

  validates :user_id, uniqueness: { scope: :project_id }
  validate :user_belongs_to_project_account

  private

  def user_belongs_to_project_account
    return if user.nil? || project.nil? || user.account_id == project.account_id

    errors.add(:user, "must belong to the project's account")
  end
end
