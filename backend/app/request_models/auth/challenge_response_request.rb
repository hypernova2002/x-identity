module Auth
  class ChallengeResponseRequest < ApplicationRequestModel
    attribute :challenge, RequestTypes::T::String.enum(*Auth::SignInFlow::CHALLENGES)
    attribute :session, RequestTypes::Token
    attribute? :code, RequestTypes::OtpCode.meta(description: "For otp and mfa_setup.")
    attribute? :new_password, RequestTypes::Password.meta(description: "For new_password.")
  end
end
