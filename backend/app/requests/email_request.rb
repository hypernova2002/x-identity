class EmailRequest < ApplicationRequest
  attribute :email, JsonModel::Types::String
end
