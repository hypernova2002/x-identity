class GroupSerializer
  include Alba::Resource

  attributes :uid, :name, :description, :default_for_new_users, :created_at, :updated_at
  attribute(:member_count) { |group| params[:member_counts] ? params[:member_counts].fetch(group.id, 0) : group.group_memberships.count }
end
