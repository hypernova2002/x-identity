require "rails_helper"

RSpec.describe IdentityProviders::CodeRedemption do
  let(:http_client) { instance_double(IdentityProviders::HttpClient, post_form: { "id_token" => "provider-id-token" }) }

  def redeem(provider, **options)
    described_class.new(provider: provider, http_client: http_client).call(code: "provider-code", **options)
  end

  it "sends Google and generic OpenID Connect providers that only take secrets in the form the secret there" do
    google = create(:identity_provider)
    form_only = create(:identity_provider, :oidc, metadata: attributes_for(:identity_provider, :oidc)[:metadata].merge("token_endpoint_auth_methods_supported" => [ "client_secret_post" ]))

    expect(redeem(google)).to eq("provider-id-token")
    redeem(form_only, code_verifier: "verifier-1")

    expect(http_client).to have_received(:post_form).with(google.endpoints["token_endpoint"], hash_including("client_id" => google.client_id, "client_secret" => "google-client-secret"))
    expect(http_client).to have_received(:post_form).with("https://idp.example.com/token", hash_including("client_secret" => "okta-secret", "code_verifier" => "verifier-1"))
  end

  it "uses Basic auth for OpenID Connect providers that take it, or don't say" do
    [ nil, %w[client_secret_basic client_secret_post] ].each do |methods|
      metadata = attributes_for(:identity_provider, :oidc)[:metadata].merge("token_endpoint_auth_methods_supported" => methods).compact
      redeem(create(:identity_provider, :oidc, metadata: metadata))
    end

    expect(http_client).to have_received(:post_form).with("https://idp.example.com/token", hash_excluding("client_secret"), basic_auth: %w[okta-client okta-secret]).twice
  end

  it "fails when the provider sends no ID token, or can't be reached" do
    provider = create(:identity_provider)
    allow(http_client).to receive(:post_form).and_return({ "access_token" => "only" }, { "id_token" => "" })

    2.times { expect { redeem(provider) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:identity_provider_error) } }

    allow(http_client).to receive(:post_form).and_raise(IdentityProviders::HttpClient::Error, "idp answered 500")
    allow(Rails.logger).to receive(:warn)
    expect { redeem(provider) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:identity_provider_error) }
    expect(Rails.logger).to have_received(:warn).with(/#{provider.uid} code redemption failed: idp answered 500/)
  end
end
