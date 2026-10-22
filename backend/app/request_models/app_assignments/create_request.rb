module AppAssignments
  class CreateRequest < ApplicationRequestModel
    attribute :principal_type, RequestTypes::T::String.enum("end_user", "group")
    attribute :principal_uid, RequestTypes::Uid
  end
end
