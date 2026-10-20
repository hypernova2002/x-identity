module Accounts
  # Creates a new account with its first user as owner.
  class SignUp
    Result = Data.define(:account, :user)

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
      end

      AuditEvents::Recorder.new(account: account).record(action: "account.created", actor: user, target: account)
      Auth::EmailVerification.new(account: account).request(email: user.email)
      Result.new(account: account, user: user)
    rescue ActiveRecord::RecordNotUnique
      raise ApiError.validation(slug: "has already been taken")
    end

    private

    def validate!(account, user, password)
      details = []
      details += ApiError.from_record(account, field_names: { name: "account_name" }).details unless account.valid?
      details += ApiError.from_record(user).details.reject { |detail| detail[:field] == "account" } unless user.valid?
      details += AuthConfiguration.new.password_violations(password).map { |message| { field: "password", message: message } }

      raise ApiError.new(:validation_failed, details: details) if details.any?
    end
  end
end
