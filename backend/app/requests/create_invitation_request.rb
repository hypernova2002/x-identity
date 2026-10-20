class CreateInvitationRequest < ApplicationRequest
  attribute :email, JsonModel::Types::String
  attribute :role, JsonModel::Types::String.enum(*Invitation.roles.keys)
end
