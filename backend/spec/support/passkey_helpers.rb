require "webauthn/fake_client"

module PasskeyHelpers
  # Saves a passkey for the user, made by a fake authenticator for the origin. Sign in with the same
  # client: it keeps the private key.
  # @return [WebAuthn::FakeClient]
  def add_passkey(user, relying_party:, origin:, synced: false, client: WebAuthn::FakeClient.new(origin, encoding: :base64url))
    registration = Passkeys::Registration.new(user: user, relying_party: relying_party, authenticated_at: Time.current)
    options = JSON.parse(registration.options.to_json)
    credential = client.create(challenge: options.dig("public_key", "challenge"), rp_id: relying_party.id, user_verified: true, backup_eligibility: synced)
    registration.finish(registration_id: options["registration_id"], credential: credential)
    client
  end

  # The fake authenticator's answer to passkey options, as a browser would send it.
  def passkey_answer(client, options, user:, rp_id:, user_verified: true)
    # The browser decodes the stored user handle to bytes when the passkey is created, and returns it base64url-encoded.
    client.get(challenge: options.dig("public_key", "challenge"), rp_id: rp_id, user_verified: user_verified, user_handle: Base64.urlsafe_decode64(user.webauthn_id))
  end
end

RSpec.configure { |config| config.include PasskeyHelpers }
