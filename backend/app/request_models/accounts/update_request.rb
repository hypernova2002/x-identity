module Accounts
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
  end
end
