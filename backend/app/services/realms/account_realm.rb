module Realms
  # Console users of one account. Their tokens are only accepted by x-identity's own console API.
  class AccountRealm
    CONSOLE_AUDIENCE = "x-identity-console".freeze

    attr_reader :account

    # @param account [Account]
    def initialize(account)
      @account = account
    end

    # @return [Account] owns the signing keys, lockout counters and auth configuration
    def owner
      account
    end

    # @return [nil]
    def project
      nil
    end

    # @return [ActiveRecord::Relation<User>]
    def users
      account.users
    end

    # @param subject [Object]
    # @return [Boolean] whether the subject is a user of this realm
    def owns?(subject)
      subject.is_a?(User) && subject.account_id == account.id
    end

    # @return [AuthConfiguration]
    def auth_configuration
      account.auth_configuration!
    end

    # @return [String]
    def token_issuer
      account.token_issuer
    end

    # @param app_client [nil] console tokens are never issued through an app client
    # @return [String]
    def audience_for(app_client)
      raise ArgumentError, "console tokens are not issued through app clients" if app_client

      CONSOLE_AUDIENCE
    end

    # @param audience [String]
    # @return [Boolean]
    def accepts_audience?(audience)
      audience == CONSOLE_AUDIENCE
    end

    # @return [String] shown next to codes in authenticator apps
    def display_name
      account.name
    end

    # @return [String] prefix for audit actions about this realm's users, e.g. `user.signed_in`
    def event_prefix
      "user"
    end

    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param app_client [nil] accepted so both realms share one signature
    # @return [AuditEvents::Recorder]
    def recorder(ip: nil, user_agent: nil, app_client: nil)
      AuditEvents::Recorder.new(account: account, ip: ip, user_agent: user_agent, app_client: app_client)
    end
  end
end
