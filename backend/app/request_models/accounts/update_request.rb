module Accounts
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name.meta(description: "The account's name.")
  end
end
