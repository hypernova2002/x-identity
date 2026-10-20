class Project < ApplicationRecord
  include HasUid

  self.uid_prefix = "proj"

  belongs_to :account
  has_many :project_memberships, dependent: :delete_all
  has_many :members, through: :project_memberships, source: :user

  validates :name, presence: true, length: { maximum: 100 }

  def self.ransackable_attributes(_auth_object = nil)
    %w[uid]
  end
end
