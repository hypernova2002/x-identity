# Requires a valid bearer access token issued by the account in the URL.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
    raise ApiError.new(:unauthorized) if token.nil?

    claims = Auth::AccessTokenVerifier.new(account: current_account).verify(token)
    user = current_account.users.active.find_by(uid: claims["sub"])
    raise ApiError.new(:invalid_token) if user.nil?
    raise ApiError.new(:invalid_token) if user.tokens_valid_after && claims["iat"] < user.tokens_valid_after.to_i

    @access_token_claims = claims
    Current.user = user
  end

  def current_user
    Current.user
  end

  # @return [String] the refresh token family behind the current access token
  def current_session_id
    @access_token_claims["sid"]
  end
end
