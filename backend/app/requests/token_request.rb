class TokenRequest < ApplicationRequest
  attribute :token, JsonModel::Types::String
end
