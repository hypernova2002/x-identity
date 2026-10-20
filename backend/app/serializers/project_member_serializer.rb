class ProjectMemberSerializer
  include Alba::Resource

  attributes :role, :created_at

  attribute(:user_uid) { |membership| membership.user.uid }
  attribute(:name) { |membership| membership.user.name }
  attribute(:email) { |membership| membership.user.email }
end
