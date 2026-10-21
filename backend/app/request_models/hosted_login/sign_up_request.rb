module HostedLogin
  class SignUpRequest < ApplicationRequestModel
    attribute :email, RequestTypes::Email
    attribute :password, RequestTypes::Password
    attribute? :name, RequestTypes::Name
  end
end
