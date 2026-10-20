class RefreshTokenRequest < ApplicationRequest
  attribute :refresh_token, JsonModel::Types::String
end
