module Mfa
  class Verifier
    # @param user [User]
    def initialize(user:)
      @user = user
    end

    # @param code [String] a TOTP code or an unused recovery code
    # @return [Boolean]
    def verify(code)
      credential = OtpCredential.confirmed.find_by(subject: @user)
      return false if credential.nil? || code.blank?

      credential.verify(code) || RecoveryCode.consume(@user, code)
    end
  end
end
