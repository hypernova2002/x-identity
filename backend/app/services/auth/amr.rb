module Auth
  # Authentication method references (`amr`, RFC 8176): how a user proved who they are. Strings,
  # because they travel in tokens, API responses and jsonb columns.
  module Amr
    PASSWORD = "pwd"
    OTP = "otp"
    # A passkey kept on one device or security key.
    HARDWARE_KEY = "hwk"
    # A passkey synced by a password manager.
    SOFTWARE_KEY = "swk"
    # The user unlocked the authenticator (fingerprint, face or PIN).
    USER_VERIFIED = "user"
    # An identity provider signed the user in.
    FEDERATED = "fed"
  end
end
