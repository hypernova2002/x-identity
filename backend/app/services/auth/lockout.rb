module Auth
  # Counts failed sign-in attempts per owner and email, and locks the email once the configured
  # threshold is reached. Keys exist for emails with no user too, so lockout reveals nothing.
  class Lockout
    # @param owner [Account]
    # @param configuration [AuthConfiguration]
    # @param store [ActiveSupport::Cache::Store]
    def initialize(owner:, configuration:, store: Rails.configuration.x.counter_store)
      @owner = owner
      @configuration = configuration
      @store = store
    end

    # @param email [String]
    # @return [Boolean]
    def locked?(email)
      @store.exist?(lock_key(email))
    end

    # @param email [String]
    def register_failure(email)
      failures = @store.increment(failures_key(email), 1, expires_in: @configuration.lockout_window)
      lock!(email) if failures.to_i >= @configuration.lockout_threshold
    end

    # Locks the email straight away, e.g. when disabling the user isn't an option.
    # @param email [String]
    def lock!(email)
      @store.write(lock_key(email), true, expires_in: @configuration.lockout_duration)
      @store.delete(failures_key(email))
    end

    # @param email [String]
    def reset(email)
      @store.delete(failures_key(email))
    end

    private

    def failures_key(email)
      "lockout:#{@owner.class.name.underscore}:#{@owner.id}:#{EmailAddress.normalize(email)}:failures"
    end

    def lock_key(email)
      "lockout:#{@owner.class.name.underscore}:#{@owner.id}:#{EmailAddress.normalize(email)}:locked"
    end
  end
end
