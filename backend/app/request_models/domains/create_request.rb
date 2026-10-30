module Domains
  class CreateRequest < ApplicationRequestModel
    attribute :hostname, RequestTypes::Hostname.meta(description: "A subdomain you control, e.g. login.example.com.")
  end
end
