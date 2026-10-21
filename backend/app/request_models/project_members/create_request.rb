module ProjectMembers
  class CreateRequest < ApplicationRequestModel
    attribute :user_uid, RequestTypes::Uid
    attribute :role, RequestTypes::ProjectRole
  end
end
