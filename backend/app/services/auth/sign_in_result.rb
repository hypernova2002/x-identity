module Auth
  # Who signed in, and how, when the sign-in ends without tokens: hosted login turns this into a
  # browser session and an authorization code instead.
  SignInCompletion = Data.define(:user, :amr, :authenticated_at)

  # Tokens (signed in), a challenge the client must answer with its session token, or, for hosted
  # login, a completion. A second-factor challenge lists the methods that can answer it.
  SignInResult = Data.define(:tokens, :challenge, :session, :recovery_codes, :completion, :mfa_methods) do
    def self.authenticated(tokens, recovery_codes: nil)
      new(tokens: tokens, challenge: nil, session: nil, recovery_codes: recovery_codes, completion: nil, mfa_methods: nil)
    end

    def self.challenged(challenge, session, recovery_codes: nil, mfa_methods: nil)
      new(tokens: nil, challenge: challenge, session: session, recovery_codes: recovery_codes, completion: nil, mfa_methods: mfa_methods)
    end

    def self.completed(completion, recovery_codes: nil)
      new(tokens: nil, challenge: nil, session: nil, recovery_codes: recovery_codes, completion: completion, mfa_methods: nil)
    end

    def challenged?
      challenge.present?
    end

    def completed?
      completion.present?
    end
  end
end
