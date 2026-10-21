Rack::Attack.cache.store = Rails.application.config.x.counter_store

Rack::Attack.throttle("requests/ip", limit: 300, period: 5.minutes) do |request|
  request.ip unless request.path == "/up"
end

Rack::Attack.throttle("sign-up/ip", limit: 10, period: 1.hour) do |request|
  request.ip if request.post? && request.path == "/v1/sign-up"
end

Rack::Attack.throttle("account-lookup/ip", limit: 30, period: 1.minute) do |request|
  request.ip if request.path.start_with?("/v1/account-lookup/")
end

Rack::Attack.throttle("auth/ip", limit: 30, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(%r{\A/v1/accounts/[^/]+/auth/})
end

Rack::Attack.throttle("auth-email/ip", limit: 5, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(%r{\A/v1/accounts/[^/]+/auth/(forgot-password|resend-confirmation)\z})
end

PROJECT_AUTH_PATH = %r{\A/v1/accounts/[^/]+/projects/[^/]+/auth/}

Rack::Attack.throttle("project-auth/ip", limit: 60, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(PROJECT_AUTH_PATH)
end

Rack::Attack.throttle("project-auth-providers/ip", limit: 30, period: 1.minute) do |request|
  request.ip if request.get? && request.path.match?(%r{#{PROJECT_AUTH_PATH}providers/})
end

Rack::Attack.throttle("project-auth-email/ip", limit: 10, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(%r{#{PROJECT_AUTH_PATH}(sign-up|resend-confirmation|forgot-password)\z})
end

Rack::Attack.throttle("project-auth-codes/ip", limit: 20, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(%r{#{PROJECT_AUTH_PATH}(confirm-sign-up|confirm-forgot-password|accept-invitation)\z})
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"]
  retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])
  error = ErrorResponse.new(code: :rate_limited)

  [ error.status, { "content-type" => "application/json", "retry-after" => retry_after.to_s }, [ error.body.to_json ] ]
end
