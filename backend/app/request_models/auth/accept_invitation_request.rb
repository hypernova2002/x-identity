module Auth
  class AcceptInvitationRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token
    attribute :name, RequestTypes::Name
    attribute :password, RequestTypes::Password
  end
end
