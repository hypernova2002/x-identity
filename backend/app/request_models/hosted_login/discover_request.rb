module HostedLogin
  class DiscoverRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
  end
end
