module Auth
  # Either tokens (signed in) or a challenge the client must answer with its session token.
  SignInResult = Data.define(:tokens, :challenge, :session, :recovery_codes) do
    def self.authenticated(tokens, recovery_codes: nil)
      new(tokens: tokens, challenge: nil, session: nil, recovery_codes: recovery_codes)
    end

    def self.challenged(challenge, session, recovery_codes: nil)
      new(tokens: nil, challenge: challenge, session: session, recovery_codes: recovery_codes)
    end

    def challenged?
      challenge.present?
    end
  end
end
