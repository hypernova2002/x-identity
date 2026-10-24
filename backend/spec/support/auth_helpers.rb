# A desktop browser, for specs about signed-in devices.
CHROME_ON_MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36".freeze

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

  # Signs the user in on a device, as a sign-in through the API would.
  # @return [Array(DeviceSession, TokenSet)]
  def signed_in_device(user, app_client: nil, ip: "203.0.113.10", user_agent: CHROME_ON_MAC)
    device = DeviceSession.start!(subject: user, amr: [ "pwd" ], authenticated_at: Time.current, ip: ip, user_agent: user_agent)
    tokens = Auth::TokenIssuer.new(realm: user.realm, app_client: app_client)
      .issue(user: user, authenticated_at: device.authenticated_at, amr: device.amr, device_session: device)
    [ device, tokens ]
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
