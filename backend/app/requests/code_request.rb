class CodeRequest < ApplicationRequest
  attribute :code, JsonModel::Types::String.meta(description: "A TOTP code or an unused recovery code.")
end
