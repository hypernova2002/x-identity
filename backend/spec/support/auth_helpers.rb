module AuthHelpers
  # @return [Hash] an Authorization header carrying a fresh access token for the user
  def auth_headers_for(user, amr: [ "pwd" ])
    tokens = Auth::TokenIssuer.new(account: user.account).issue(user: user, authenticated_at: Time.current, amr: amr)
    { "Authorization" => "Bearer #{tokens.access_token}" }
  end

  # @return [Auth::TokenSet]
  def tokens_for(user, amr: [ "pwd" ])
    Auth::TokenIssuer.new(account: user.account).issue(user: user, authenticated_at: Time.current, amr: amr)
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
