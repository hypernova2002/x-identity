class ChangePasswordRequest < ApplicationRequest
  attribute :current_password, JsonModel::Types::String
  attribute :new_password, JsonModel::Types::String
end
