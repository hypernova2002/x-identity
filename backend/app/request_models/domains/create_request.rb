module Domains
  class CreateRequest < ApplicationRequestModel
    attribute :hostname, RequestTypes::T::String.constrained(min_size: 1, max_size: 253)
      .meta(description: "A subdomain you control, e.g. login.example.com.")
  end
end
