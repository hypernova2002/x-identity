class AcceptInvitationRequest < ApplicationRequest
  attribute :token, JsonModel::Types::String
  attribute :name, JsonModel::Types::String
  attribute :password, JsonModel::Types::String
end
