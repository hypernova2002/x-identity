class AddProjectMemberRequest < ApplicationRequest
  attribute :user_uid, JsonModel::Types::String
  attribute :role, JsonModel::Types::String.enum(*ProjectMembership.roles.keys)
end
