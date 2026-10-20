class ChallengeResponseRequest < ApplicationRequest
  attribute :challenge, JsonModel::Types::String.enum(*Auth::SignInFlow::CHALLENGES)
  attribute :session, JsonModel::Types::String
  attribute? :code, JsonModel::Types::String.meta(description: "For totp and mfa_setup.")
  attribute? :new_password, JsonModel::Types::String.meta(description: "For new_password.")
end
