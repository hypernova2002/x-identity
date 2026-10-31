require "rails_helper"

RSpec.describe IdentityProviders::Management do
  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:discovery) { instance_double(IdentityProviders::Discovery) }
  let(:http_client) { instance_double(IdentityProviders::HttpClient) }
  let(:management) { described_class.new(actor: admin, project: project, discovery: discovery, http_client: http_client) }
  let(:staff) { create(:group, project: project, name: "Staff") }
  let(:sales) { create(:group, project: project, name: "Sales") }

  def validation_detail(&block)
    expect(&block).to raise_error(ApiError) { |error| return error.details.first }
  end

  describe "group mappings" do
    it "maps provider values to the project's groups, once each" do
      provider = management.create(
        kind: "google", name: "Google", client_id: "g-1", client_secret: "s",
        group_mappings: [ { value: "staff", group_uid: staff.uid }, { value: "staff", group_uid: staff.uid }, { value: "sales", group_uid: sales.uid } ]
      )

      expect(provider.group_mappings.map { |mapping| [ mapping.value, mapping.group ] }).to contain_exactly([ "staff", staff ], [ "sales", sales ])
    end

    it "refuses groups that aren't the project's, saving nothing" do
      other_group = create(:group)

      detail = validation_detail do
        management.create(kind: "google", name: "Google", client_id: "g-1", client_secret: "s", group_mappings: [ { value: "x", group_uid: other_group.uid } ])
      end

      expect(detail).to include(field: "group_mappings", code: "unknown_groups", params: { groups: [ other_group.uid ] })
      expect(project.identity_providers.reload).to be_empty
    end

    it "replaces the mappings on update, recording that they changed, and keeps them when none are sent" do
      provider = management.create(kind: "google", name: "Google", client_id: "g-1", client_secret: "s", group_mappings: [ { value: "staff", group_uid: staff.uid } ])

      management.update(provider, group_mappings: [ { value: "sales", group_uid: sales.uid } ])
      expect(provider.group_mappings.reload.map(&:value)).to eq([ "sales" ])
      expect(AuditEvent.last).to have_attributes(action: "identity_provider.updated", metadata: { "changes" => { "group_mappings" => "changed" } })

      management.update(provider, name: "Google Workspace")
      expect(provider.group_mappings.reload.map(&:value)).to eq([ "sales" ])

      management.update(provider, group_mappings: [])
      expect(provider.group_mappings.reload).to be_empty
    end
  end

  describe "updating" do
    let!(:provider) { management.create(kind: "google", name: "Google", client_id: "g-1", client_secret: "old-secret") }

    it "records what changed, hiding secrets, and records nothing when nothing did" do
      management.update(provider, name: "Workspace", client_secret: "new-secret")
      expect(AuditEvent.last.metadata).to eq("changes" => { "name" => { "from" => "Google", "to" => "Workspace" }, "client_secret" => "changed" })

      expect { management.update(provider, name: "Workspace", client_secret: "") }.not_to change(AuditEvent, :count)
      expect(provider.reload.client_secret).to eq("new-secret")
    end

    it "refuses invalid changes, saving nothing" do
      expect { management.update(provider, name: "") }.to raise_error(ApiError) { |error| expect(error.code).to eq(:validation_failed) }
      expect(provider.reload.name).to eq("Google")
    end

    it "reloads an OpenID Connect provider's discovery document only when its URL changes" do
      document = ->(issuer) { IdentityProvider::METADATA_KEYS.index_with { |key| "#{issuer}/#{key}" }.merge("issuer" => issuer) }
      allow(discovery).to receive(:fetch).and_return(document.("https://idp.test"), document.("https://idp2.test"))
      oidc = management.create(kind: "oidc", name: "Okta", client_id: "o-1", client_secret: "s", discovery_url: "https://idp.test")

      management.update(oidc, name: "Okta SSO")
      management.update(oidc, discovery_url: "https://idp2.test")

      expect(discovery).to have_received(:fetch).twice
      expect(oidc.reload.metadata["issuer"]).to eq("https://idp2.test")
    end
  end

  describe "reading SAML metadata" do
    it "takes either XML or a URL, not both or neither" do
      [ {}, { metadata_xml: "<x/>", metadata_url: "https://idp.test/metadata" } ].each do |source|
        expect(validation_detail { management.parse_saml_metadata(**source) }).to include(field: "metadata", code: "xml_or_url_required")
      end
    end

    it "says when the URL can't be loaded" do
      allow(http_client).to receive(:get_text).and_raise(IdentityProviders::HttpClient::Error, "idp.test answered 500")

      expect(validation_detail { management.parse_saml_metadata(metadata_url: "https://idp.test/metadata") })
        .to include(field: "metadata_url", code: "not_loadable", params: { reason: "idp.test answered 500" })
    end
  end

  it "refuses an invalid new provider, recording nothing" do
    expect { management.create(kind: "google", name: "", client_id: "g-1", client_secret: "s") }
      .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "name") }
    expect(AuditEvent.where(action: "identity_provider.created")).to be_empty
  end

  it "is for those who can manage the project's settings" do
    member = create(:user, account: project.account)

    expect { described_class.new(actor: member, project: project).create(kind: "google", name: "Google") }
      .to raise_error(ApiError) { |error| expect(error.code).to eq(:forbidden) }
  end
end
