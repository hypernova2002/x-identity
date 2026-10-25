module Passkeys
  class ChallengeOptionsRequest < ApplicationRequestModel
    attribute :session, RequestTypes::Token.meta(description: "The session of a challenge whose mfa_methods include passkey.")
  end
end
