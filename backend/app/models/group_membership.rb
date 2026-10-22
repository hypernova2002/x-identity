class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :end_user

  validates :end_user_id, uniqueness: { scope: :group_id }
end
