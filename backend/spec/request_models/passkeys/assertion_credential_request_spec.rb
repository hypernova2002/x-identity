require "rails_helper"

RSpec.describe Passkeys::AssertionCredentialRequest do
  let(:valid_body) { PasskeyCredentialBodies::ASSERTION.except(:authenticatorAttachment, :clientExtensionResults) }

  it_behaves_like "passkey credential fields",
    response: PasskeyCredentialBodies::ASSERTION_RESPONSE, other_response: PasskeyCredentialBodies::ATTESTATION_RESPONSE
end
