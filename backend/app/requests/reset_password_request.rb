class ResetPasswordRequest < ApplicationRequest
  attribute :token, JsonModel::Types::String
  attribute :password, JsonModel::Types::String
end
