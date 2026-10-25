class SignInResultSerializer
  # The challenge fields, as hosted login also returns them.
  # @param result [Auth::SignInResult] a challenged result
  # @return [Hash]
  def self.challenge_body(result)
    { challenge: result.challenge.name, session: result.session, mfa_methods: result.challenge.mfa_methods.presence }.compact
  end

  # @param result [Auth::SignInResult]
  def initialize(result)
    @result = result
  end

  # @return [Hash]
  def serializable_hash
    body = @result.challenged? ? self.class.challenge_body(@result) : TokenSetSerializer.new(@result.tokens).serializable_hash
    body[:recovery_codes] = @result.recovery_codes if @result.recovery_codes
    body
  end
end
