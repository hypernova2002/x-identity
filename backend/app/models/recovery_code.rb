# A single-use MFA backup code. Only a digest is stored.
class RecoveryCode < ApplicationRecord
  COUNT = 10

  belongs_to :subject, polymorphic: true

  validates :code_digest, presence: true

  scope :unused, -> { where(used_at: nil) }

  # @param code [String]
  # @return [String]
  def self.digest(code)
    OpenSSL::Digest::SHA256.hexdigest(normalize(code))
  end

  # @param code [String]
  # @return [String]
  def self.normalize(code)
    code.to_s.downcase.gsub(/[^a-z0-9]/, "")
  end

  # Replaces the subject's codes with a fresh set.
  # @param subject [ApplicationRecord]
  # @return [Array<String>] the plaintext codes, shown to the user once
  def self.regenerate_for!(subject)
    codes = Array.new(COUNT) { SecureRandom.alphanumeric(10).downcase.scan(/.{5}/).join("-") }

    transaction do
      where(subject: subject).delete_all
      codes.each { |code| create!(subject: subject, code_digest: digest(code)) }
    end

    codes
  end

  # @param subject [ApplicationRecord]
  # @param code [String]
  # @return [Boolean] whether an unused matching code was found and used up
  def self.consume(subject, code)
    unused.where(subject: subject, code_digest: digest(code)).limit(1).update_all(used_at: Time.current) == 1
  end
end
