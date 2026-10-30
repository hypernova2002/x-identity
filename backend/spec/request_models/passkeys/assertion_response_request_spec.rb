require "rails_helper"

RSpec.describe Passkeys::AssertionResponseRequest do
  let(:valid_body) { PasskeyCredentialBodies::ASSERTION_RESPONSE.except(:userHandle) }

  it_behaves_like "a required field", :clientDataJSON
  it_behaves_like "a string field", :clientDataJSON, min: 1, max: 8192
  it_behaves_like "a required field", :authenticatorData
  it_behaves_like "a string field", :authenticatorData, min: 1, max: 8192
  it_behaves_like "a required field", :signature
  it_behaves_like "a string field", :signature, min: 1, max: 2048

  it_behaves_like "an optional field", :userHandle
  it_behaves_like "a string field", :userHandle, min: 1, max: 86, nullable: true
  it_behaves_like "an optional field", :attestationObject
  it_behaves_like "a string field", :attestationObject, min: 1, max: 65_536, nullable: true
end
