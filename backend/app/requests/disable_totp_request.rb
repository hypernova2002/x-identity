class DisableTotpRequest < ApplicationRequest
  attribute :current_password, JsonModel::Types::String
  attribute :code, JsonModel::Types::String.meta(description: "A TOTP code or an unused recovery code.")
end
