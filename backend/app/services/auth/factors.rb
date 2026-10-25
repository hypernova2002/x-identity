module Auth
  # Which authentication methods (`amr`, RFC 8176) prove multi-factor authentication: a one-time
  # code, or a passkey (hardware or synced key) the user unlocked.
  module Factors
    PASSKEY_METHODS = %w[hwk swk].freeze

    module_function

    # @param amr [Array<String>]
    # @return [Boolean]
    def mfa?(amr)
      amr = Array(amr)
      amr.include?("otp") || (amr.include?("user") && amr.intersect?(PASSKEY_METHODS))
    end
  end
end
