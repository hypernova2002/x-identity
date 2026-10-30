module HostedLogin
  class SignUpRequest < ApplicationRequestModel
    attribute :email, RequestTypes::Email
    attribute :password, SignInFields::NewPassword
    attribute? :name, RequestTypes::Name.meta(description: "The end user's name.")
  end
end
