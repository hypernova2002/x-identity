class SignUpRequest < ApplicationRequest
  attribute :account_name, JsonModel::Types::String
  attribute :slug, JsonModel::Types::String
  attribute :name, JsonModel::Types::String
  attribute :email, JsonModel::Types::String
  attribute :password, JsonModel::Types::String
end
