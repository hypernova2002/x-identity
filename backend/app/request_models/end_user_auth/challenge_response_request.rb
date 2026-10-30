module EndUserAuth
  class ChallengeResponseRequest < ClientRequest
    attribute :challenge, SignInFields::Challenge
    attribute :session, SignInFields::ChallengeSession
    attribute? :code, SignInFields::ChallengeCode
    attribute? :new_password, SignInFields::ChallengeNewPassword
    attribute? :authentication_id, SignInFields::ChallengeAuthenticationId
    attribute? :registration_id, SignInFields::ChallengeRegistrationId
    attribute? :credential, SignInFields::ChallengeCredential
  end
end
