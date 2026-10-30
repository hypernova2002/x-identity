module ProjectMembers
  class CreateRequest < ApplicationRequestModel
    attribute :user_uid, RequestTypes::Uid.meta(description: "The uid of the account's user to add.")
    attribute :role, RequestTypes::ProjectRole
  end
end
