Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins { |source, _env| CorsOriginPolicy.new.allowed?(source) }

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Total Total-Capped Per-Page Link Retry-After],
      max_age: 600
  end
end
