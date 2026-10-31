require "rails_helper"

RSpec.describe Passkeys::Authentication do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:relying_party) { Passkeys::RelyingParties.console(account) }
  let(:origin) { relying_party.allowed_origins.first }
  let(:client) { add_passkey(user, relying_party: relying_party, origin: origin) }
  let(:authentication) { described_class.new(realm: account.realm, relying_party: relying_party) }

  def sign_in(answer_for: user)
    options = JSON.parse(authentication.options.to_json)
    credential = passkey_answer(client, options, user: answer_for, rp_id: relying_party.id)
    authentication.verify(authentication_id: options["authentication_id"], credential: credential)
  end

  def error_code(&block)
    expect(&block).to raise_error(ApiError) { |error| return error.code }
  end

  it "signs the owner in with the passkey" do
    expect(sign_in.first).to eq(user)
  end

  it "refuses an answer naming another user, counting it as a failure" do
    client
    lockout = instance_spy(Auth::Lockout, locked?: false)
    allow(Auth::Lockout).to receive(:new).and_return(lockout)

    someone_else = create(:user, account: account, webauthn_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false))

    expect(error_code { sign_in(answer_for: someone_else) }).to eq(:invalid_passkey)
    expect(lockout).to have_received(:register_failure).with(user.email)
  end

  it "refuses a locked-out user, and a disabled one" do
    client
    allow(Auth::Lockout).to receive(:new).and_return(instance_double(Auth::Lockout, locked?: true))
    expect(error_code { sign_in }).to eq(:too_many_attempts)

    allow(Auth::Lockout).to receive(:new).and_call_original
    user.update!(status: "disabled")
    expect(error_code { sign_in }).to eq(:invalid_passkey)
  end
end

RSpec.describe Passkeys::Registration do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:relying_party) { Passkeys::RelyingParties.console(account) }

  def register
    add_passkey(user, relying_party: relying_party, origin: relying_party.allowed_origins.first)
  end

  def error(&block)
    expect(&block).to raise_error(ApiError) { |raised| return raised }
  end

  it "refuses a passkey past the user's limit" do
    stub_const("WebauthnCredential::MAX_PER_USER", 1)
    register

    expect(error { register }.code).to eq(:validation_failed)
  end

  it "says the passkey is already saved when the database finds it twice" do
    allow_any_instance_of(WebauthnCredential).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    expect(error { register }).to have_attributes(code: :invalid_passkey, reason: :passkey_already_saved)
  end
end

RSpec.describe Passkeys::RelyingParties do
  it "uses the console's origin without a port when it's the scheme's default" do
    configured = Rails.configuration.x.console_base_url
    Rails.configuration.x.console_base_url = "https://console.example.com"

    expect(described_class.console(create(:account)).allowed_origins).to eq([ "https://console.example.com" ])
  ensure
    Rails.configuration.x.console_base_url = configured
  end

  it "offers no passkeys to an end user signing in through neither hosted login nor an app" do
    end_user = create(:end_user)
    end_user.project.auth_configuration!.update!(passkeys: "optional")

    expect(described_class.for_sign_in(end_user)).to be_nil
  end
end

RSpec.describe "Realms" do
  it "issues console tokens only without an app client, and end-user tokens only through the project's" do
    account_realm = create(:account).realm
    project = create(:project)

    expect(account_realm.project).to be_nil
    expect { account_realm.audience_for(create(:app_client)) }.to raise_error(ArgumentError)
    expect { project.realm.audience_for(nil) }.to raise_error(ArgumentError)
    expect { project.realm.audience_for(create(:app_client)) }.to raise_error(ArgumentError)
  end
end
