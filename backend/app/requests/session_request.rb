class SessionRequest < ApplicationRequest
  attribute :session, JsonModel::Types::String
end
