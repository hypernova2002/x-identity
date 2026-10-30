module HostedLogin
  class SignInRequest < ApplicationRequestModel
    attribute :email, SignInFields::SignInEmail
    attribute :password, SignInFields::SignInPassword
  end
end
