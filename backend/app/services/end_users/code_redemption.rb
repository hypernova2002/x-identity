module EndUsers
  # Finds the one-time token an end user is redeeming, either by the opaque token from an email
  # link or by email address plus the 6-digit code. Every failure looks the same to the caller.
  class CodeRedemption
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for rate limiting and the audit log
    # @param user_agent [String, nil]
    def initialize(project:, ip: nil, user_agent: nil)
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @param purpose [Symbol] a {OneTimeToken} purpose
    # @param email [String, nil]
    # @param code [String, nil]
    # @param token [String, nil]
    # @return [OneTimeToken] a usable token belonging to one of the project's end users
    # @raise [ApiError] `validation_failed` when neither a token nor email and code are given,
    #   `invalid_code` when they don't match, `too_many_attempts` when the caller's IP is blocked
    def find!(purpose:, email: nil, code: nil, token: nil)
      record = if token.present?
        OneTimeToken.find_usable(token, purpose: purpose)
      elsif email.present? && code.present?
        by_code(purpose, email, code)
      else
        raise ApiError.validation(:code, :required_with_email)
      end

      raise ApiError.new(:invalid_code) unless record && @project.realm.owns?(record.subject) && record.subject.active?

      record
    end

    private

    def by_code(purpose, email, code)
      end_user = @project.end_users.find_by(email: email)
      record = end_user && OneTimeToken.current_for(end_user, purpose: purpose)
      max_attempts = @project.auth_configuration!.email_code_max_attempts

      matched = CodeThrottle.new(project: @project, ip: @ip, user_agent: @user_agent).attempt(email: email, code: code) do
        record&.code_matches?(code, max_attempts: max_attempts) || false
      end
      record if matched
    end
  end
end
