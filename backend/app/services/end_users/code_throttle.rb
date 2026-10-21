module EndUsers
  # Limits wrong email codes along three dimensions, so codes can't be guessed by spreading attempts
  # out: per email address (across every code it is sent, so requesting new codes doesn't reset it),
  # per code value (across every address, against trying one guess on many addresses), and per IP.
  # Unknown addresses count exactly like real ones.
  class CodeThrottle
    MAX_FAILURES_PER_IP = 30
    IP_WINDOW = 1.hour

    # @param project [Project]
    # @param ip [String, nil] the caller's IP address; not limited when nil
    # @param user_agent [String, nil] for the audit log
    # @param store [ActiveSupport::Cache::Store]
    def initialize(project:, ip: nil, user_agent: nil, store: Rails.configuration.x.counter_store)
      @project = project
      @configuration = project.auth_configuration!
      @ip = ip
      @user_agent = user_agent
      @store = store
    end

    # Runs a code check unless a limit has been reached, and counts it when it fails.
    # @param email [String]
    # @param code [String]
    # @yieldreturn [Boolean] whether the code is right
    # @return [Boolean] false when the code is wrong or a limit has been reached
    # @raise [ApiError] `too_many_attempts` when the caller's IP has been blocked
    def attempt(email:, code:)
      limit = reached_limit(email, code)
      raise ApiError.new(:too_many_attempts) if limit == :ip
      return false if limit
      return true if yield

      register_failure(email, code)
      false
    end

    # Whether a code value is currently refused, so it isn't sent out.
    # @param code [String]
    # @return [Boolean]
    def code_blocked?(code)
      count(code_key(code)) >= @configuration.email_code_max_failures_per_code
    end

    private

    def reached_limit(email, code)
      return :ip if @ip.present? && count(ip_key) >= MAX_FAILURES_PER_IP
      return :email if count(email_key(email)) >= @configuration.email_code_max_failures_per_email

      :code if code_blocked?(code)
    end

    def register_failure(email, code)
      window = @configuration.email_code_failure_window
      record_limit("email", email: email) if increment(email_key(email), window) == @configuration.email_code_max_failures_per_email
      record_limit("code", code_fingerprint: code_digest(code).first(12)) if increment(code_key(code), window) == @configuration.email_code_max_failures_per_code
      record_limit("ip") if @ip.present? && increment(ip_key, IP_WINDOW) == MAX_FAILURES_PER_IP
    end

    def record_limit(limit, **metadata)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
        .record(action: "end_user.code_limit_reached", metadata: { limit: limit, **metadata })
    end

    def count(key)
      @store.read(key, raw: true).to_i
    end

    def increment(key, window)
      @store.increment(key, 1, expires_in: window).to_i
    end

    def code_digest(code)
      OneTimeToken.code_digest(code)
    end

    def email_key(email)
      "codes:project:#{@project.id}:email:#{OpenSSL::Digest::SHA256.hexdigest(EmailAddress.normalize(email))}"
    end

    def code_key(code)
      "codes:project:#{@project.id}:code:#{code_digest(code)}"
    end

    def ip_key
      "codes:ip:#{@ip}"
    end
  end
end
