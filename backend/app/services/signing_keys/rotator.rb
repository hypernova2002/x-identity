module SigningKeys
  # Returns the owner's current signing key, generating a new one when none exists, the configured
  # algorithm changed, or the key is due for rotation. Retired keys stay published long enough for
  # every token they signed to expire.
  class Rotator
    RETIRED_KEY_PUBLISH_PERIOD = (AuthConfiguration::MAX_ACCESS_TOKEN_TTL_MINUTES + 5).minutes

    # @param owner [Account]
    # @param configuration [AuthConfiguration]
    def initialize(owner:, configuration:)
      @owner = owner
      @configuration = configuration
    end

    # @return [SigningKey]
    def current
      key = latest_signing_key
      return key if usable?(key)

      @configuration.with_lock do
        key = latest_signing_key
        next key if usable?(key)

        @owner.signing_keys.signing.find_each { |signing_key| signing_key.retire!(publish_for: RETIRED_KEY_PUBLISH_PERIOD) }
        SigningKey.generate!(owner: @owner, algorithm: @configuration.signing_algorithm)
      end
    end

    private

    def latest_signing_key
      @owner.signing_keys.signing.order(activated_at: :desc).first
    end

    def usable?(key)
      key.present? &&
        key.algorithm == @configuration.signing_algorithm &&
        !key.due_for_rotation?(@configuration.signing_key_rotation_days)
    end
  end
end
