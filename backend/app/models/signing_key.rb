# An asymmetric key pair that signs access tokens for its owner (an Account, and later a Project).
class SigningKey < ApplicationRecord
  ALGORITHMS = %w[ES256 RS256 PS256].freeze
  RSA_KEY_BITS = 2048

  belongs_to :owner, polymorphic: true

  encrypts :private_key

  validates :kid, presence: true, uniqueness: true
  validates :algorithm, inclusion: { in: ALGORITHMS }
  validates :public_key, :private_key, :activated_at, presence: true

  scope :signing, -> { where(retired_at: nil) }
  scope :published, -> { where(retired_at: nil).or(where("published_until > ?", Time.current)) }

  # @param owner [ApplicationRecord]
  # @param algorithm [String] one of {ALGORITHMS}
  # @return [SigningKey]
  def self.generate!(owner:, algorithm:)
    key = algorithm == "ES256" ? OpenSSL::PKey::EC.generate("prime256v1") : OpenSSL::PKey::RSA.generate(RSA_KEY_BITS)

    create!(
      owner: owner,
      algorithm: algorithm,
      kid: SecureRandom.base58(16),
      public_key: key.public_to_pem,
      private_key: key.private_to_pem,
      activated_at: Time.current
    )
  end

  # @return [OpenSSL::PKey::PKey]
  def signing_key
    OpenSSL::PKey.read(private_key)
  end

  # @return [OpenSSL::PKey::PKey]
  def verification_key
    OpenSSL::PKey.read(public_key)
  end

  # @return [Hash] the public key as a JWK
  def jwk
    JWT::JWK.new(verification_key, { kid: kid, use: "sig", alg: algorithm }).export
  end

  # @param rotation_days [Integer]
  # @return [Boolean]
  def due_for_rotation?(rotation_days)
    activated_at < rotation_days.days.ago
  end

  # Stops signing with this key but keeps publishing it until tokens it signed have expired.
  # @param publish_for [ActiveSupport::Duration]
  def retire!(publish_for:)
    now = Time.current
    update!(retired_at: now, published_until: now + publish_for)
  end
end
