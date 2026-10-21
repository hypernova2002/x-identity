module Users
  class UpdateRequest < ApplicationRequestModel
    attribute? :role, RequestTypes::AccountRole
    attribute? :status, RequestTypes::T::String.enum(*User.statuses.keys)
  end
end
