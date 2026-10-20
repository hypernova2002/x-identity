class UpdateProjectMemberRequest < ApplicationRequest
  attribute :role, JsonModel::Types::String.enum(*ProjectMembership.roles.keys)
end
