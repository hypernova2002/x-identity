class Invitation < ApplicationRecord
  include HasUid

  self.uid_prefix = "inv"

  TTL = 7.days

  belongs_to :account
  belongs_to :invited_by, class_name: "User", optional: true

  enum :role, { owner: "owner", admin: "admin", member: "member" }, validate: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[email role]
  end

  normalizes :email, with: ->(email) { EmailAddress.normalize(email) }

  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil).where("expires_at > ?", Time.current) }

  # @param token [String]
  # @return [String]
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  # Creates an invitation and returns it with its plaintext token, which is never stored.
  # @return [Array(Invitation, String)]
  def self.issue!(**attributes)
    token = SecureRandom.base58(32)
    invitation = create!(**attributes, token_digest: digest(token), expires_at: TTL.from_now)
    [ invitation, token ]
  end

  # @param token [String]
  # @return [Invitation, nil] the pending invitation matching the token
  def self.find_pending_by_token(token)
    pending.find_by(token_digest: digest(token.to_s))
  end

  def accept!
    update!(accepted_at: Time.current)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
