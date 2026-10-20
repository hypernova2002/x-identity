class SignInResultSerializer
  # @param result [Auth::SignInResult]
  def initialize(result)
    @result = result
  end

  # @return [Hash]
  def serializable_hash
    body = @result.challenged? ? { challenge: @result.challenge, session: @result.session } : TokenSetSerializer.new(@result.tokens).serializable_hash
    body[:recovery_codes] = @result.recovery_codes if @result.recovery_codes
    body
  end
end
