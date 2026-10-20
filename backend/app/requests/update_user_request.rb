class UpdateUserRequest < ApplicationRequest
  attribute? :role, JsonModel::Types::String.enum(*User.roles.keys)
  attribute? :status, JsonModel::Types::String.enum(*User.statuses.keys)
end
