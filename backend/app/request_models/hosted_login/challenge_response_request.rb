module HostedLogin
  class ChallengeResponseRequest < ApplicationRequestModel
    attribute :challenge, RequestTypes::T::String.enum(*Auth::Challenges::ALL)
    attribute :session, RequestTypes::Token
    attribute? :code, RequestTypes::OtpCode.meta(description: "For otp and mfa_setup.")
    attribute? :new_password, RequestTypes::Password.meta(description: "For new_password.")
    attribute? :authentication_id, RequestTypes::Token.meta(description: "For passkey: from the passkey options for this challenge.")
    attribute? :registration_id, RequestTypes::Token.meta(description: "For passkey_setup: from the passkey setup options.")
    attribute? :credential, RequestTypes::T::Hash.meta(description: "For passkey: the browser's answer; for passkey_setup: the new passkey (a PublicKeyCredential), as JSON.")
  end
end
