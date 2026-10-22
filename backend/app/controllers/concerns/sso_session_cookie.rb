# The hosted login's single sign-on session cookie, shared by a project's OpenID Connect and SAML
# endpoints. Scoped to the project's path, so each project has its own session.
module SsoSessionCookie
  extend ActiveSupport::Concern

  included do
    include ActionController::Cookies
  end

  private

  def session_token
    cookies[BrowserSession::COOKIE_NAME]
  end

  def store_session(token, expires_at)
    cookies[BrowserSession::COOKIE_NAME] = { value: token, expires: expires_at, **sso_cookie_options }
  end

  def clear_session
    cookies.delete(BrowserSession::COOKIE_NAME, **sso_cookie_options)
  end

  def sso_cookie_options
    {
      path: URI.parse(current_project.token_issuer).path,
      httponly: true,
      same_site: :lax,
      secure: Rails.configuration.x.app_base_url.start_with?("https://")
    }
  end
end
