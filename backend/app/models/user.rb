class User < ApplicationRecord
  include HasUid

  self.uid_prefix = "usr"

  belongs_to :account
  has_many :project_memberships, dependent: :delete_all
  has_many :projects, through: :project_memberships
  has_many :refresh_tokens, as: :subject, dependent: :delete_all
  has_many :one_time_tokens, as: :subject, dependent: :delete_all
  has_many :recovery_codes, as: :subject, dependent: :delete_all
  has_one :otp_credential, as: :subject, dependent: :delete

  enum :role, { owner: "owner", admin: "admin", member: "member" }, validate: true
  enum :status, { active: "active", disabled: "disabled" }, validate: true, default: "active"

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email,
    presence: true,
    length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { scope: :account_id }
  validates :password_digest, presence: true
  validates :password_changed_at, presence: true

  # @return [Boolean] whether the user can manage the account (owners and admins)
  def account_admin?
    owner? || admin?
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
    return false if configuration.password_max_age_days.nil?

    password_changed_at < configuration.password_max_age_days.days.ago
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

  def disable!
    transaction do
      update!(status: :disabled)
      revoke_all_sessions!
    end
  end

  def enable!
    update!(status: :active)
  end
end
