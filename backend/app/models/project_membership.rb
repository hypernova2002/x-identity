class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum :role, { admin: "admin", developer: "developer", viewer: "viewer" }, validate: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[role]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user]
  end

  validates :user_id, uniqueness: { scope: :project_id }
  validate :user_belongs_to_project_account

  private

  def user_belongs_to_project_account
    return if user.nil? || project.nil? || user.account_id == project.account_id

    errors.add(:user, :other_account)
  end
end
