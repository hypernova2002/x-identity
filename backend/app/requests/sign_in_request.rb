class SignInRequest < ApplicationRequest
  attribute :email, JsonModel::Types::String
  attribute :password, JsonModel::Types::String
end
