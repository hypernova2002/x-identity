module Passkeys
  class ChallengeOptionsRequest < ApplicationRequestModel
    attribute :session, SignInFields::PasskeyChallengeSession
  end
end
