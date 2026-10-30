require "rails_helper"

RSpec.describe Passkeys::AttestationResponseRequest do
  let(:valid_body) { PasskeyCredentialBodies::ATTESTATION_RESPONSE.except(:transports) }

  it_behaves_like "a required field", :clientDataJSON
  it_behaves_like "a string field", :clientDataJSON, min: 1, max: 8192
  it_behaves_like "a required field", :attestationObject
  it_behaves_like "a string field", :attestationObject, min: 1, max: 65_536

  it_behaves_like "an optional field", :transports
  it_behaves_like "an array field", :transports, max: 10, item: "internal", item_max: 32, invalid_items: [ "" ]
  it_behaves_like "an optional field", :authenticatorData
  it_behaves_like "a string field", :authenticatorData, min: 1, max: 8192
  it_behaves_like "an optional field", :publicKey
  it_behaves_like "a string field", :publicKey, min: 1, max: 8192, nullable: true
  it_behaves_like "an optional field", :publicKeyAlgorithm
  it_behaves_like "a field accepting", :publicKeyAlgorithm, [ -7, -257 ]
  it_behaves_like "a field rejecting", :publicKeyAlgorithm, [ "-7", 1.5 ]
  it_behaves_like "a nullable field", :publicKeyAlgorithm, false
end
