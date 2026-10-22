module Groups
  class AddMemberRequest < ApplicationRequestModel
    attribute :end_user_uid, RequestTypes::Uid
  end
end
