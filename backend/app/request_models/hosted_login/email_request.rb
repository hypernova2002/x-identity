module HostedLogin
  class EmailRequest < ApplicationRequestModel
    attribute :email, SignInFields::SignInEmail
  end
end
