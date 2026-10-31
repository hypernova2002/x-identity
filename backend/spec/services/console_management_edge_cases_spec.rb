require "rails_helper"

RSpec.describe "Console management edge cases" do
  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }

  describe SamlApps::Management do
    let(:http_client) { instance_double(IdentityProviders::HttpClient) }
    let(:management) { described_class.new(actor: admin, project: project, http_client: http_client) }

    it "takes metadata as XML or a URL, and says when the URL can't be loaded" do
      expect { management.parse_metadata }.to raise_error(ApiError) { |error| expect(error.details.first).to include(code: "xml_or_url_required") }
      allow(http_client).to receive(:get_text).and_raise(IdentityProviders::HttpClient::Error, "sp answered 404")

      expect { management.parse_metadata(metadata_url: "https://sp.example.com/metadata") }
        .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "metadata_url", code: "not_loadable") }
    end

    it "clears optional fields sent blank, and records nothing when nothing changed" do
      app = create(:saml_app, :with_slo, project: project)

      management.update(app, slo_url: "")
      expect(app.reload.slo_url).to be_nil
      expect { management.update(app, name: app.name) }.not_to change(AuditEvent, :count)
    end

    it "notes a certificate change without recording the certificate" do
      app = create(:saml_app, project: project)

      management.update(app, sp_certificate: SamlCertificate.generate!(project: create(:project), status: "active").certificate)

      expect(AuditEvent.last.metadata["changes"]).to eq("sp_certificate" => "changed")
    end
  end

  describe ApiResources::Management do
    let(:management) { described_class.new(actor: admin, project: project) }
    let(:api) { management.create(name: "Orders", identifier: "https://orders.example.com", scopes: [ { name: "orders:read" } ]) }

    it "refuses invalid changes, records nothing when nothing changed, and leaves grants alone without new scopes" do
      grant = create(:app_client, :machine, project: project).api_grants.create!(api_resource: api, scopes: [ "orders:read" ])

      expect { management.update(api, name: "") }.to raise_error(ApiError) { |error| expect(error.code).to eq(:validation_failed) }
      expect { management.update(api.reload, name: "Orders") }.not_to change(AuditEvent, :count)
      management.update(api, name: "Order API")
      expect(grant.reload.scopes).to eq([ "orders:read" ])
    end
  end

  describe Invitations::Accept do
    let(:account) { project.account }
    let(:accept) { described_class.new(account: account) }

    def invitation_token(email: "new@acme.test")
      Invitations::Create.new(inviter: admin).call(email: email, role: "member")
      Invitation.issue!(account: account, invited_by: admin, email: email, role: "member").last
    end

    it "refuses when the address got a user meanwhile" do
      token = invitation_token
      create(:user, account: account, email: "new@acme.test")

      expect { accept.call(token: token, name: "New", password: "correct horse battery staple") }
        .to raise_error(ApiError) { |error| expect(error.code).to eq(:email_taken) }
    end

    it "reports a bad name and a weak password together" do
      token = invitation_token

      expect { accept.call(token: token, name: "", password: "short") }
        .to raise_error(ApiError) { |error| expect(error.details.pluck(:field)).to include("name", "password") }
    end

    it "says the address is taken when the unique index catches a concurrent acceptance" do
      token = invitation_token
      allow_any_instance_of(User).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

      expect { accept.call(token: token, name: "New", password: "correct horse battery staple") }
        .to raise_error(ApiError) { |error| expect(error.code).to eq(:email_taken) }
    end
  end

  describe Invitations::Create do
    it "reports an invalid address as a field error" do
      expect { described_class.new(inviter: admin).call(email: "not-an-email", role: "member") }
        .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "email") }
    end
  end
end
