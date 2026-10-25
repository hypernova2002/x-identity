# Requires a valid bearer access token issued by the controller's `token_realm`: the account's
# console users, or a project's end users.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
    raise ApiError.new(:unauthorized) if token.nil?

    claims = Auth::AccessTokenVerifier.new(realm: token_realm).verify(token)
    user = token_realm.users.active.find_by(uid: claims["sub"])
    raise ApiError.new(:invalid_token) if user.nil?
    raise ApiError.new(:invalid_token) if user.tokens_valid_after && claims["iat"] < user.tokens_valid_after.to_i

    @access_token_claims = claims
    @current_user = user
  end

  # @return [Realms::AccountRealm, Realms::ProjectRealm]
  def token_realm
    current_account.realm
  end

  # @return [User, EndUser]
  def current_user
    @current_user
  end

  # @return [Time] when the user last signed in, from the access token
  def authenticated_at
    Time.zone.at(@access_token_claims["auth_time"])
  end

  # @return [String] the refresh token family behind the current access token
  def current_session_id
    @access_token_claims["sid"]
  end
end
