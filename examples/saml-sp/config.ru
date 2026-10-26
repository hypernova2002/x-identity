# A tiny SAML service provider for trying x-identity's SAML apps by hand. It shows what the identity
# provider sent: whether the response checked out, the NameID and the attributes.
#
# Runs on the backend image, which already has ruby-saml and Puma, as the saml-sp Compose service.
#   IDP_METADATA_URL  the project's SAML metadata, as this container reaches the backend
#   SP_BASE_URL       where the browser reaches this app, e.g. http://localhost:5192
require "erb"
require "onelogin/ruby-saml"
require "rack"

module TestSp
  module_function

  def base_url
    ENV.fetch("SP_BASE_URL", "http://localhost:5192")
  end

  def sp_settings
    OneLogin::RubySaml::Settings.new.tap do |settings|
      settings.sp_entity_id = "#{base_url}/metadata"
      settings.assertion_consumer_service_url = "#{base_url}/acs"
    end
  end

  # The identity provider's details come from its metadata on every request, so changes such as a
  # new signing certificate show up straight away.
  def settings
    metadata_url = ENV["IDP_METADATA_URL"].to_s
    raise "Set IDP_METADATA_URL to the project's SAML metadata URL (see docs/examples.md)." if metadata_url.empty?

    OneLogin::RubySaml::IdpMetadataParser.new.parse_remote(metadata_url, true, settings: sp_settings)
  end

  def page(title, body)
    [ 200, { "content-type" => "text/html; charset=utf-8" }, [ LAYOUT.result_with_hash(title: title, body: body) ] ]
  end

  def h(value)
    ERB::Util.html_escape(value.to_s)
  end

  LAYOUT = ERB.new(<<~HTML)
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
      <title><%= title %> · Test SAML SP</title>
      <style>
        body { font: 15px/1.5 system-ui, sans-serif; max-width: 52rem; margin: 2rem auto; padding: 0 1rem; color: #0f172a; }
        code, pre { font: 13px/1.4 ui-monospace, monospace; } pre { background: #f8fafc; border: 1px solid #e2e8f0; padding: .75rem; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; } td, th { border-top: 1px solid #e2e8f0; padding: .4rem .5rem; text-align: left; vertical-align: top; }
        .ok { color: #15803d; font-weight: 600; } .bad { color: #b91c1c; font-weight: 600; } a.button { display: inline-block; background: #185fa5; color: #fff; padding: .5rem 1rem; border-radius: 6px; text-decoration: none; }
      </style>
    </head>
    <body><h1><%= title %></h1><%= body %></body>
    </html>
  HTML

  def home
    page("Test SAML SP", <<~HTML)
      <p>A SAML service provider for trying a project's SAML app. Sign in from here (SP-initiated), or launch it from the app portal (IdP-initiated).</p>
      <p><a class="button" href="/login">Sign in with x-identity</a></p>
      <h2>Set up the SAML app</h2>
      <table>
        <tr><th>Entity ID</th><td><code>#{h sp_settings.sp_entity_id}</code></td></tr>
        <tr><th>ACS URL</th><td><code>#{h sp_settings.assertion_consumer_service_url}</code></td></tr>
        <tr><th>Metadata</th><td><a href="/metadata"><code>#{h sp_settings.sp_entity_id}</code></a></td></tr>
        <tr><th>Identity provider</th><td><code>#{h ENV.fetch("IDP_METADATA_URL", "not set")}</code></td></tr>
      </table>
    HTML
  end

  def login
    url = OneLogin::RubySaml::Authrequest.new.create(settings, RelayState: "sp-initiated")
    [ 302, { "location" => url }, [] ]
  end

  def acs(request)
    response = OneLogin::RubySaml::Response.new(request.POST["SAMLResponse"].to_s, settings: settings, allowed_clock_drift: 5)
    valid = response.is_valid?
    attributes = response.attributes.all.map { |name, values| "<tr><th>#{h name}</th><td>#{values.map { |value| h(value) }.join('<br>')}</td></tr>" }.join
    page("SAML response", <<~HTML)
      <p class="#{valid ? 'ok' : 'bad'}">#{valid ? '✔ Valid: signed by the identity provider, for this app, and in date.' : '✘ Not valid'}</p>
      #{valid ? '' : "<ul>#{response.errors.map { |error| "<li>#{h error}</li>" }.join}</ul>"}
      <table>
        <tr><th>NameID</th><td><code>#{h response.name_id}</code> (#{h response.name_id_format})</td></tr>
        <tr><th>Issuer</th><td><code>#{h response.issuers.join(', ')}</code></td></tr>
        <tr><th>Session index</th><td><code>#{h response.sessionindex}</code></td></tr>
        <tr><th>RelayState</th><td><code>#{h request.POST['RelayState']}</code> #{request.POST['RelayState'] == 'sp-initiated' ? '(SP-initiated)' : '(IdP-initiated)'}</td></tr>
      </table>
      <h2>Attributes</h2>
      #{attributes.empty? ? '<p>None.</p>' : "<table>#{attributes}</table>"}
      <h2>Response XML</h2>
      <pre>#{h response.document.to_s}</pre>
      <p><a href="/">Back</a></p>
    HTML
  end

  def metadata
    [ 200, { "content-type" => "application/samlmetadata+xml" }, [ OneLogin::RubySaml::Metadata.new.generate(sp_settings, true) ] ]
  end

  def call(env)
    request = Rack::Request.new(env)
    case [ request.request_method, request.path_info ]
    when [ "GET", "/" ] then home
    when [ "GET", "/login" ] then login
    when [ "POST", "/acs" ] then acs(request)
    when [ "GET", "/metadata" ] then metadata
    else [ 404, { "content-type" => "text/plain" }, [ "Not found" ] ]
    end
  rescue StandardError => error
    page("Something went wrong", "<p class=\"bad\">#{h error.message}</p><p><a href=\"/\">Back</a></p>")
  end
end

run TestSp
