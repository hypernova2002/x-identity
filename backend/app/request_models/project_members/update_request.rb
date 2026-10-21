module ProjectMembers
  class UpdateRequest < ApplicationRequestModel
    attribute :role, RequestTypes::ProjectRole
  end
end
