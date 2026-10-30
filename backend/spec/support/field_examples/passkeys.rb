# Passkey credentials as browsers send them (PublicKeyCredential.toJSON()), for the requests that
# take one. See Passkeys::Fields.
module PasskeyCredentialBodies
  ASSERTION_RESPONSE = {
    clientDataJSON: "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0", authenticatorData: "SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MFAAAAAQ",
    signature: "MEUCIQCsignature", userHandle: "dXNlci1oYW5kbGU"
  }.freeze
  ATTESTATION_RESPONSE = {
    clientDataJSON: "eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0", attestationObject: "o2NmbXRkbm9uZQ", transports: %w[internal hybrid]
  }.freeze
  ASSERTION = {
    id: "YXNzZXJ0aW9u", rawId: "YXNzZXJ0aW9u", type: "public-key", authenticatorAttachment: "platform",
    clientExtensionResults: {}, response: ASSERTION_RESPONSE
  }.freeze
  ATTESTATION = {
    id: "YXR0ZXN0YXRpb24", rawId: "YXR0ZXN0YXRpb24", type: "public-key", authenticatorAttachment: "platform",
    clientExtensionResults: {}, response: ATTESTATION_RESPONSE
  }.freeze
end

RSpec.shared_examples "a passkey assertion field" do |field|
  it_behaves_like "a field accepting", field, [ PasskeyCredentialBodies::ASSERTION ]
  it_behaves_like "a field rejecting", field,
    [ PasskeyCredentialBodies::ATTESTATION, PasskeyCredentialBodies::ASSERTION.except(:response), "credential" ]
  it_behaves_like "a nullable field", field, false
end

RSpec.shared_examples "a passkey attestation field" do |field|
  it_behaves_like "a field accepting", field, [ PasskeyCredentialBodies::ATTESTATION ]
  it_behaves_like "a field rejecting", field,
    [ PasskeyCredentialBodies::ASSERTION, PasskeyCredentialBodies::ATTESTATION.except(:response), "credential" ]
  it_behaves_like "a nullable field", field, false
end

# The challenge response's credential: an assertion for passkey, the new passkey for passkey_setup.
RSpec.shared_examples "a passkey challenge credential field" do |field|
  it_behaves_like "a field accepting", field, [ PasskeyCredentialBodies::ASSERTION, PasskeyCredentialBodies::ATTESTATION ]
  it_behaves_like "a field rejecting", field, [ PasskeyCredentialBodies::ASSERTION.merge(response: {}), "credential" ]
  it_behaves_like "a nullable field", field, false
end

# The fields of Passkeys::AssertionCredentialRequest and AttestationCredentialRequest. `response` is
# a valid response for the credential, and `other_response` the other kind.
RSpec.shared_examples "passkey credential fields" do |response:, other_response:|
  it_behaves_like "a required field", :id
  it_behaves_like "a string field", :id, min: 1, max: 1364
  it_behaves_like "a required field", :rawId
  it_behaves_like "a string field", :rawId, min: 1, max: 1364
  it_behaves_like "a required field", :type
  it_behaves_like "an enum field", :type, values: %w[public-key]
  it_behaves_like "an optional field", :authenticatorAttachment
  it_behaves_like "an enum field", :authenticatorAttachment, values: %w[platform cross-platform], nullable: true
  it_behaves_like "an optional field", :clientExtensionResults
  it_behaves_like "a hash field", :clientExtensionResults, max: 16, nullable: true
  it_behaves_like "a required field", :response
  it_behaves_like "a field accepting", :response, [ response ]
  it_behaves_like "a field rejecting", :response, [ other_response, {}, "response" ]
  it_behaves_like "a nullable field", :response, false
end
