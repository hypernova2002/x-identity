module Auth
  # Tokens (signed in), a {Challenge} the client must answer with its session token, or, for hosted
  # login, a completion.
  SignInResult = Data.define(:tokens, :challenge, :session, :recovery_codes, :completion) do
    def self.authenticated(tokens, recovery_codes: nil)
      new(tokens: tokens, challenge: nil, session: nil, recovery_codes: recovery_codes, completion: nil)
    end

    # @param challenge [Challenge]
    # @param session [String]
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
