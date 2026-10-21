module HostedLogin
  class EmailRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
  end
end
