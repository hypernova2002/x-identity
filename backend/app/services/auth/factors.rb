module Auth
  # Which authentication methods (`amr`, RFC 8176) prove multi-factor authentication: a one-time
  # code, or a passkey (hardware or synced key) the user unlocked.
  module Factors
    PASSKEY_METHODS = [ Amr::HARDWARE_KEY, Amr::SOFTWARE_KEY ].freeze

    module_function

    # @param amr [Array<String>]
    # @return [Boolean]
    def mfa?(amr)
      Array(amr).include?(Amr::OTP) || passkey?(amr)
    end

    # @param amr [Array<String>]
    # @return [Boolean] whether the user unlocked a passkey
    def passkey?(amr)
      amr = Array(amr)
      amr.include?(Amr::USER_VERIFIED) && amr.intersect?(PASSKEY_METHODS)
    end
  end
end
