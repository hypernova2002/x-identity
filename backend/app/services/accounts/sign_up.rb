module Accounts
  # Creates a new account with its first user as owner.
  class SignUp
    Result = Data.define(:account, :user)

    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(ip: nil, user_agent: nil)
      @ip = ip
      @user_agent = user_agent
    end

    # @return [Result]
    # @raise [ApiError] `validation_failed`
    def call(account_name:, slug:, name:, email:, password:)
      account = Account.new(name: account_name, slug: slug)
      user = account.users.new(name: name, email: email, role: :owner, password_digest: "pending", password_changed_at: Time.current)

      validate!(account, user, password)
      user.password_digest = Passwords::Hasher.new.digest(password)

      ActiveRecord::Base.transaction do
        account.save!
        account.create_auth_configuration!
        user.save!
        account.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "account.created", actor: user, target: account)
      end

      Auth::EmailVerification.new(account: account, ip: @ip, user_agent: @user_agent).request(email: user.email)
      Result.new(account: account, user: user)
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.validation(:slug, :taken)
    end

    private

    def validate!(account, user, password)
      details = []
      details += ApiError.from_record(account, field_names: { name: "account_name" }).details unless account.valid?
      details += ApiError.from_record(user).details.reject { |detail| detail[:field] == "account" } unless user.valid?
      details += AuthConfiguration.new.password_violations(password)

      raise ApiError.new(:validation_failed, details: details) if details.any?
    end
  end
end
