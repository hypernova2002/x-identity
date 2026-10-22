module Oidc
  # RP-initiated logout: ends the browser's single sign-on session, logs it out of the SAML apps it
  # signed in to, then sends the browser to the app's registered post-logout redirect URI, or to the
  # hosted signed-out page. Tokens the app holds are the app's to discard; revoking them is what the
  # revocation endpoint is for.
  class Logout
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(project:, ip: nil, user_agent: nil)
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @param session_token [String, nil] from the single sign-on cookie
    # @param params [Hash{String => String}] id_token_hint, client_id, post_logout_redirect_uri, state
    # @return [String] where to send the browser
    def call(session_token:, params:)
      session = end_session(session_token)
      destination = destination_for(params)
      session ? SamlIdp::Logout.new(project: @project, ip: @ip, user_agent: @user_agent).start(session, final_url: destination) : destination
    end

    private

    def destination_for(params)
      redirect_uri = params["post_logout_redirect_uri"].presence
      return Urls.hosted_page(@project, "signed-out") unless redirect_uri

      app_client = client_for(params)
      return Urls.append_query(redirect_uri, state: params["state"].presence) if app_client&.post_logout_redirect_uri_allowed?(redirect_uri)

      Urls.hosted_page(@project, "error", error: "invalid_request", error_description: "You're signed out, but the app's post-logout address isn't registered.")
    end

    # @return [BrowserSession, nil] the session that was ended
    def end_session(session_token)
      return nil if session_token.blank?

      session = BrowserSession.find_by(project: @project, token_digest: BrowserSession.digest(session_token), revoked_at: nil)
      return nil unless session

      session.revoke!
      @project.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: "end_user.signed_out", actor: session.end_user, target: session.end_user, metadata: { sso: true })
      session
    end

    def client_for(params)
      client_id = params["client_id"].presence || audience_from(params["id_token_hint"])
      @project.app_clients.enabled.find_by(uid: client_id.to_s) if client_id
    end

    # The hint may have expired; only its signature and issuer matter here.
    def audience_from(id_token)
      return nil if id_token.blank?

      _payload, header = JWT.decode(id_token, nil, false)
      key = @project.signing_keys.published.find_by(kid: header["kid"])
      return nil unless key

      claims, = JWT.decode(id_token, key.verification_key, true, algorithm: key.algorithm, iss: @project.token_issuer, verify_iss: true, verify_expiration: false)
      Array(claims["aud"]).first
    rescue JWT::DecodeError
      nil
    end
  end
end
