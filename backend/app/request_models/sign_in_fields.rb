# Field types of the sign-in requests, which console users (Auth), end users through the API
# (EndUserAuth) and hosted login (HostedLogin) send alike.
module SignInFields
  T = RequestTypes::T

  Challenge = T::String.enum(*Auth::Challenges::ALL).meta(description: "The challenge being answered, from the sign-in response.")
  ChallengeSession = RequestTypes::Token.meta(description: "The session from the challenge.")
  ChallengeCode = RequestTypes::OtpCode.meta(description: "For otp and mfa_setup.")
  ChallengeNewPassword = RequestTypes::Password.meta(description: "For new_password.")
  ChallengeAuthenticationId = RequestTypes::Token.meta(description: "For passkey: from the passkey options for this challenge.")
  ChallengeRegistrationId = RequestTypes::Token.meta(description: "For passkey_setup: from the passkey setup options.")
  ChallengeCredential = (Passkeys::AssertionCredentialRequest | Passkeys::AttestationCredentialRequest)
    .meta(description: "For passkey: the browser's answer; for passkey_setup: the new passkey (a PublicKeyCredential), as JSON.")

  SignInEmail = RequestTypes::EmailLookup.meta(description: "The email address the user signs in with, in any case.")
  SignInPassword = RequestTypes::Password.meta(description: "The user's password.")
  NewPassword = RequestTypes::Password.meta(description: "The new password. It must meet the password policy.")
  RefreshToken = RequestTypes::Token.meta(description: "The refresh token from signing in.")
  MfaSetupSession = RequestTypes::Token.meta(description: "The session of the mfa_setup challenge.")

  PasskeyChallengeSession = RequestTypes::Token.meta(description: "The session of a challenge whose mfa_methods include passkey.")
  PasskeySetupSession = RequestTypes::Token.meta(description: "The session of the passkey_setup challenge.")
  PasskeyAuthenticationId = RequestTypes::Token.meta(description: "From the passkey options.")
  PasskeyCredential = Passkeys::AssertionCredentialRequest.meta(description: "The browser's answer (a PublicKeyCredential), as JSON (its toJSON()).")

  EmailLinkToken = RequestTypes::Token.meta(description: "From the link in the email, instead of email and code.")
  EmailLinkCode = RequestTypes::EmailCode.meta(description: "The 6-digit code from the email, sent with email instead of token.")
  EmailLinkEmail = RequestTypes::EmailLookup.meta(description: "The address the email was sent to, sent with code instead of token.")
end
