module Passwords
  # Argon2id password hashing. Parameters are fixed by the platform, not configurable per account.
  class Hasher
    PARAMS = if Rails.env.test?
      { t_cost: 1, m_cost: 8, p_cost: 1 }.freeze
    else
      { t_cost: 2, m_cost: 16, p_cost: 1 }.freeze
    end

    # @param password [String]
    # @return [String] an encoded Argon2id digest
    def digest(password)
      Argon2::Password.create(password, **PARAMS)
    end

    # Compares in roughly constant time whether or not a digest exists, so unknown emails
    # can't be told apart from wrong passwords by timing.
    # @param password [String, nil]
    # @param digest [String, nil]
    # @return [Boolean]
    def matches?(password, digest)
      if digest.blank?
        Argon2::Password.verify_password(password.to_s, self.class.dummy_digest)
        return false
      end

      Argon2::Password.verify_password(password.to_s, digest)
    rescue Argon2::ArgonHashFail
      false
    end

    def self.dummy_digest
      @dummy_digest ||= Argon2::Password.create(SecureRandom.hex(16), **PARAMS)
    end
  end
end
