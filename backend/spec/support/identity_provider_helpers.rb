require "webmock/rspec"

# A fake identity provider: ID tokens signed with a test key, and stubbed JWKS, discovery and
# token endpoints. Provider hosts resolve to a public address so the SSRF guard lets them through.
module IdentityProviderHelpers
  PROVIDER_KEY = OpenSSL::PKey::RSA.generate(2048)
  PROVIDER_JWK = JWT::JWK.new(PROVIDER_KEY, kid: "provider-key-1")
  PUBLIC_ADDRESS = "93.184.216.34".freeze

  # @return [String] a signed ID token from the provider, with sensible defaults
  def provider_id_token(provider, key: PROVIDER_JWK, **claims)
    now = Time.current.to_i
    payload = {
      iss: provider.issuers.first, aud: provider.client_id, sub: "provider-user-1", iat: now, exp: now + 600,
      nonce: "nonce-for-specs-123456", email: "casey@shop.test", email_verified: true, name: "Casey Provider"
    }.merge(claims).compact
    JWT.encode(payload, key.signing_key, "RS256", { kid: key[:kid] })
  end

  def stub_provider_jwks(provider, jwk: PROVIDER_JWK)
    stub_request(:get, provider.endpoints["jwks_uri"]).to_return(json_response(JWT::JWK::Set.new(jwk).export))
  end

  def stub_provider_token(provider, id_token)
    stub_request(:post, provider.endpoints["token_endpoint"]).to_return(json_response({ access_token: "provider-access", id_token: id_token }))
  end

  def stub_discovery(issuer, **overrides)
    document = {
      issuer: issuer,
      authorization_endpoint: "#{issuer}/authorize",
      token_endpoint: "#{issuer}/token",
      jwks_uri: "#{issuer}/jwks",
      code_challenge_methods_supported: [ "S256" ]
    }.merge(overrides)
    stub_request(:get, "#{issuer}/.well-known/openid-configuration").to_return(json_response(document))
  end

  def json_response(body, status: 200)
    { status: status, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  # @return [Array(String, String)] a PKCE code verifier and its S256 challenge
  def pkce_pair
    verifier = SecureRandom.urlsafe_base64(48)
    [ verifier, Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false) ]
  end
end

RSpec.configure do |config|
  config.include IdentityProviderHelpers

  config.before do
    allow(Resolv).to receive(:getaddresses).and_return([ IdentityProviderHelpers::PUBLIC_ADDRESS ])
  end
end
