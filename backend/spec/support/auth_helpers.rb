module AuthHelpers
  # @return [Hash] an Authorization header carrying a fresh access token for the user
  def auth_headers_for(user, amr: [ "pwd" ])
    { "Authorization" => "Bearer #{tokens_for(user, amr: amr).access_token}" }
  end

  # @param app_client [AppClient, nil] required for end users
  # @return [Auth::TokenSet]
  def tokens_for(user, amr: [ "pwd" ], app_client: nil)
    Auth::TokenIssuer.new(realm: user.realm, app_client: app_client).issue(user: user, authenticated_at: Time.current, amr: amr)
  end

  def current_totp_for(user)
    ROTP::TOTP.new(user.otp_credential.secret).now
  end

  def error_code
    response.parsed_body.dig("error", "code")
  end
end

RSpec.configure do |config|
  config.include AuthHelpers
  config.include ActiveSupport::Testing::TimeHelpers

  config.before do
    Rails.configuration.x.counter_store.clear
  end
end
