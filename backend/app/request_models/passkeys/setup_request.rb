module Passkeys
  class SetupRequest < ApplicationRequestModel
    attribute :session, SignInFields::PasskeySetupSession
  end
end
