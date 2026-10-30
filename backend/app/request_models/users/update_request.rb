module Users
  class UpdateRequest < ApplicationRequestModel
    attribute? :role, RequestTypes::AccountRole
    attribute? :status, RequestTypes::T::String.enum(*User.statuses.keys).meta(description: "Disabled users can't sign in, and their sessions end.")
  end
end
