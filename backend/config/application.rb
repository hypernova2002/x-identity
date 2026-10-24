require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module XIdentity
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    # The hosted login's single sign-on session is a cookie on the OAuth endpoints.
    config.middleware.use ActionDispatch::Cookies

    config.x.app_base_url = ENV.fetch("APP_BASE_URL", "http://localhost:3000")
    config.x.console_base_url = ENV.fetch("CONSOLE_BASE_URL", "http://localhost:5173")
    config.x.mail_from = ENV.fetch("MAIL_FROM", "x-identity <no-reply@x-identity.localhost>")
    # Offline IP location database (DB-IP Lite city, GeoIP2 format); see GeoIp. Location is blank without it.
    config.x.geoip_database_path = ENV.fetch("GEOIP_DATABASE_PATH", Rails.root.join("vendor/geoip/dbip-city-lite.mmdb").to_s)

    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    config.exceptions_app = ->(env) { ErrorsController.action(:show).call(env) }

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
