class SignInResultSerializer
  # @param result [Auth::SignInResult]
  def initialize(result)
    @result = result
  end

  # @return [Hash]
  def serializable_hash
    body = @result.challenged? ? { challenge: @result.challenge, session: @result.session, mfa_methods: @result.mfa_methods }.compact : TokenSetSerializer.new(@result.tokens).serializable_hash
    body[:recovery_codes] = @result.recovery_codes if @result.recovery_codes
    body
  end
end
