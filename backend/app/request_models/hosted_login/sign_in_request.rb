module HostedLogin
  class SignInRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
    attribute :password, RequestTypes::Password
  end
end
