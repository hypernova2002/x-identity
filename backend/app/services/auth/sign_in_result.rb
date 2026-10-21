module Auth
  # Who signed in, and how, when the sign-in ends without tokens: hosted login turns this into a
  # browser session and an authorization code instead.
  SignInCompletion = Data.define(:user, :amr, :authenticated_at)

  # Tokens (signed in), a challenge the client must answer with its session token, or, for hosted
  # login, a completion.
  SignInResult = Data.define(:tokens, :challenge, :session, :recovery_codes, :completion) do
    def self.authenticated(tokens, recovery_codes: nil)
      new(tokens: tokens, challenge: nil, session: nil, recovery_codes: recovery_codes, completion: nil)
    end

    def self.challenged(challenge, session, recovery_codes: nil)
      new(tokens: nil, challenge: challenge, session: session, recovery_codes: recovery_codes, completion: nil)
    end

    def self.completed(completion, recovery_codes: nil)
      new(tokens: nil, challenge: nil, session: nil, recovery_codes: recovery_codes, completion: completion)
    end

    def challenged?
      challenge.present?
    end

    def completed?
      completion.present?
    end
  end
end
