# Sign-in state shared by console users (User) and project end users (EndUser): credentials,
# sessions, MFA and email verification. Each includer defines `realm`.
module Authenticatable
  extend ActiveSupport::Concern

  included do
    has_many :refresh_tokens, as: :subject, dependent: :delete_all
    has_many :one_time_tokens, as: :subject, dependent: :delete_all
    has_many :recovery_codes, as: :subject, dependent: :delete_all
    has_one :otp_credential, as: :subject, dependent: :delete

    enum :status, { active: "active", disabled: "disabled" }, validate: true, default: "active"

    normalizes :email, with: ->(email) { EmailAddress.normalize(email) }
  end

  # @return [Boolean]
  def email_verified?
    email_verified_at.present?
  end

  # @return [Boolean] whether the user has a confirmed TOTP credential
  def mfa_enabled?
    otp_credential&.confirmed? || false
  end

  # @param configuration [AuthConfiguration]
  # @return [Boolean]
  def password_expired?(configuration)
    return false if configuration.password_max_age.nil? || password_changed_at.nil?

    password_changed_at < configuration.password_max_age.ago
  end

  def verify_email!
    update!(email_verified_at: Time.current) unless email_verified?
  end

  # @param password_digest [String] an Argon2 digest from {Passwords::Hasher}
  def change_password!(password_digest)
    update!(password_digest: password_digest, password_changed_at: Time.current)
  end

  def record_sign_in!
    update!(last_sign_in_at: Time.current)
  end

  # Invalidates every access token issued so far and revokes all refresh tokens.
  def revoke_all_sessions!
    transaction do
      update!(tokens_valid_after: Time.current)
      refresh_tokens.active.update_all(revoked_at: Time.current)
    end
  end

  # Revokes every refresh token family except `keep_family_id`.
  # @param keep_family_id [String, nil]
  def revoke_other_sessions!(keep_family_id:)
    refresh_tokens.active.where.not(family_id: keep_family_id).update_all(revoked_at: Time.current)
  end

  # Turns off MFA and deletes the user's recovery codes.
  def remove_mfa!
    transaction do
      OtpCredential.where(subject: self).delete_all
      RecoveryCode.where(subject: self).delete_all
    end
    association(:otp_credential).reset
  end

  # Counts a wrong TOTP or recovery code. Safe against concurrent requests.
  # @return [Integer] consecutive failures, including this one
  def register_mfa_failure!
    self.class.where(id: id).update_all("failed_mfa_attempts = failed_mfa_attempts + 1")
    self.failed_mfa_attempts = self.class.where(id: id).pick(:failed_mfa_attempts)
  end

  def reset_mfa_failures!
    update_column(:failed_mfa_attempts, 0) if failed_mfa_attempts.positive?
  end

  def disable!
    transaction do
      update!(status: :disabled)
      revoke_all_sessions!
    end
  end

  # Re-enables the user and clears their failed MFA attempts.
  def enable!
    update!(status: :active, failed_mfa_attempts: 0)
  end
end
