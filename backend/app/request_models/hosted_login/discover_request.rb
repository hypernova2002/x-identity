module HostedLogin
  class DiscoverRequest < ApplicationRequestModel
    attribute :email, SignInFields::SignInEmail
  end
end
