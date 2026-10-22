# A named set of a project's end users, used to assign apps and sent to apps as the `groups` claim
# or a SAML attribute. New end users join every group marked `default_for_new_users`.
class Group < ApplicationRecord
  include HasUid

  self.uid_prefix = "grp"

  belongs_to :project
  has_many :group_memberships, dependent: :delete_all
  has_many :end_users, through: :group_memberships
  has_many :app_assignments, as: :principal, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :project_id, case_sensitive: false }
  validates :description, length: { maximum: 500 }, allow_nil: true
  validates :default_for_new_users, inclusion: { in: [ true, false ] }

  scope :for_new_users, -> { where(default_for_new_users: true) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name]
  end
end
