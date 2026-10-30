require "rails_helper"

RSpec.describe Passkeys::FinishRegistrationRequest do
  let(:valid_body) { { registration_id: "registration-id", credential: PasskeyCredentialBodies::ATTESTATION } }

  it_behaves_like "a required field", :registration_id
  it_behaves_like "a token field", :registration_id

  it_behaves_like "a required field", :credential
  it_behaves_like "a passkey attestation field", :credential

  it_behaves_like "an optional field", :name
  it_behaves_like "a string field", :name, min: 1, max: 60, nullable: true
end
