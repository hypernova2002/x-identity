module HostedLogin
  class ConfirmSignUpRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup.meta(description: "The address the code was sent to.")
    attribute :code, RequestTypes::EmailCode
  end
end
