module Auth
  # A challenge a sign-in stops at. A second factor (otp or passkey) also lists the methods that can
  # answer it. Clients see these as `challenge` and `mfa_methods`.
  Challenge = Data.define(:name, :mfa_methods) do
    # @param name [String] one of {Challenges::ALL}
    # @param mfa_methods [Array<String>] some of {Challenges::MFA_METHODS}
    def initialize(name:, mfa_methods: [])
      super(name: name, mfa_methods: Array(mfa_methods).freeze)
    end

    # @param answer [String] the challenge a client says it's answering
    # @return [Boolean] whether that answers this challenge: the challenge itself, or a passkey where one is offered
    def answered_by?(answer)
      answer == name || (answer == Challenges::PASSKEY && mfa_methods.include?(Challenges::PASSKEY))
    end
  end
end
