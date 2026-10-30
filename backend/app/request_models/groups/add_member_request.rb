module Groups
  class AddMemberRequest < ApplicationRequestModel
    attribute :end_user_uid, RequestTypes::Uid.meta(description: "The uid of the end user to add.")
  end
end
