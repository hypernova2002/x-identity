module HostedLogin
  class ConfirmSignUpRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
    attribute :code, RequestTypes::EmailCode
  end
end
