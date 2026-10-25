module Auth
  # The challenges a sign-in can stop at, as clients see them in `challenge`, and the methods that
  # can answer a second-factor challenge, as they see them in `mfa_methods`.
  module Challenges
    OTP = "otp"
    PASSKEY = "passkey"
    NEW_PASSWORD = "new_password"
    MFA_SETUP = "mfa_setup"
    PASSKEY_SETUP = "passkey_setup"

    ALL = [ OTP, PASSKEY, NEW_PASSWORD, MFA_SETUP, PASSKEY_SETUP ].freeze
    MFA_METHODS = [ OTP, PASSKEY ].freeze
  end
end
