require "rails_helper"

RSpec.describe Passkeys::AttestationCredentialRequest do
  let(:valid_body) { PasskeyCredentialBodies::ATTESTATION.except(:authenticatorAttachment, :clientExtensionResults) }

  it_behaves_like "passkey credential fields",
    response: PasskeyCredentialBodies::ATTESTATION_RESPONSE, other_response: PasskeyCredentialBodies::ASSERTION_RESPONSE
end
