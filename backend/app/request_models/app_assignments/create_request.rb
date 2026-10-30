module AppAssignments
  class CreateRequest < ApplicationRequestModel
    attribute :principal_type, RequestTypes::T::String.enum("end_user", "group").meta(description: "Whether the app is assigned to an end user or a group.")
    attribute :principal_uid, RequestTypes::Uid.meta(description: "The uid of the end user or group.")
  end
end
