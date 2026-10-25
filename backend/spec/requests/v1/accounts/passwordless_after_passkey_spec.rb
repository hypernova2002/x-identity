require "rails_helper"

RSpec.describe "No passwords once a passkey is set up", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account, email: "casey@acme.test") }
  let(:console) { URI.parse(Rails.configuration.x.console_base_url) }
  let(:console_origin) { "#{console.scheme}://#{console.host}:#{console.port}" }

  before { account.auth_configuration!.update!(passkeys: "optional", passwordless_after_passkey: true) }

  def sign_in_with_password(password = "correct horse battery staple")
    post "/v1/accounts/#{account.uid}/auth/sign-in", params: { email: "casey@acme.test", password: password }, as: :json
    response.parsed_body
  end

  it "needs passkeys on" do
    configuration = account.auth_configuration!

    expect(configuration.update(passkeys: "off")).to be(false)
    expect(configuration.errors[:passwordless_after_passkey]).to include("needs passkeys to be on")
  end

  it "refuses the password of users with a passkey, but only once it's right" do
    add_passkey(user, relying_party: Passkeys::RelyingParties.console(account), origin: console_origin)

    sign_in_with_password("wrong password")
    expect(error_code).to eq("invalid_credentials")

    sign_in_with_password
    expect(response).to have_http_status(:forbidden)
    expect(error_code).to eq("passkey_required")
  end

  it "still accepts passwords from users without a passkey, and when the option is off" do
    expect(sign_in_with_password).to have_key("access_token")

    add_passkey(user, relying_party: Passkeys::RelyingParties.console(account), origin: console_origin)
    account.auth_configuration!.update!(passwordless_after_passkey: false)
    expect(sign_in_with_password).to have_key("access_token")
  end

  it "lets a user who reset their password by email back in to add a new passkey, once" do
    add_passkey(user, relying_party: Passkeys::RelyingParties.console(account), origin: console_origin)
    _record, token = OneTimeToken.issue!(subject: user, purpose: :password_reset)
    Auth::PasswordReset.new(account: account).reset(token: token, password: "a brand new passphrase")

    challenge = sign_in_with_password("a brand new passphrase")
    expect(challenge["challenge"]).to eq("passkey_setup")

    post "/v1/accounts/#{account.uid}/auth/passkey-setup", params: { session: challenge["session"] }, as: :json
    options = response.parsed_body
    credential = WebAuthn::FakeClient.new(console_origin, encoding: :base64url).create(challenge: options.dig("public_key", "challenge"), rp_id: console.host, user_verified: true)
    post "/v1/accounts/#{account.uid}/auth/respond-to-challenge", params: {
      challenge: "passkey_setup", session: challenge["session"], registration_id: options["registration_id"], credential: credential
    }, as: :json
    expect(response.parsed_body).to have_key("access_token")
    expect(user.reload.passkey_recovery_until).to be_nil

    sign_in_with_password("a brand new passphrase")
    expect(error_code).to eq("passkey_required")
  end

  it "ends the recovery after an hour" do
    add_passkey(user, relying_party: Passkeys::RelyingParties.console(account), origin: console_origin)
    user.start_passkey_recovery!

    travel(61.minutes) { sign_in_with_password }

    expect(error_code).to eq("passkey_required")
  end

  it "keeps passwords for end users where their passkey can't be used" do
    project = create(:project, account: account)
    domain = project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
    project.auth_configuration!.update!(passkeys: "optional", passwordless_after_passkey: true)
    end_user = create(:end_user, project: project, email: "jo@acme.com")
    add_passkey(end_user, relying_party: Passkeys::RelyingParties.for(end_user, endpoints: ProjectEndpoints.new(project, domain: domain)), origin: "https://login.acme.com")
    native_app = create(:app_client, project: project)
    web_app = create(:app_client, project: project, allowed_origins: [ "https://app.acme.com" ])
    base = URI.parse(project.token_issuer).path

    post "#{base}/auth/sign-in", params: { client_id: native_app.uid, email: "jo@acme.com", password: "correct horse battery staple" }, as: :json
    expect(response.parsed_body).to have_key("access_token")

    post "#{base}/auth/sign-in", params: { client_id: web_app.uid, email: "jo@acme.com", password: "correct horse battery staple" }, as: :json
    expect(error_code).to eq("passkey_required")
  end
end
