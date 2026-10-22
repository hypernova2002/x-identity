require "rails_helper"
require "openapi_helper"

RSpec.describe "SAML apps", type: :openapi do
  openapi_schema :public_api

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:developer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "developer") } }
  let(:sp_metadata) do
    <<~XML
      <md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" entityID="https://wiki.example.com/saml">
        <md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
          <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://wiki.example.com/saml/slo"/>
          <md:NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</md:NameIDFormat>
          <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://wiki.example.com/saml/acs-2" index="2"/>
          <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://wiki.example.com/saml/acs" index="1" isDefault="true"/>
        </md:SPSSODescriptor>
      </md:EntityDescriptor>
    XML
  end

  describe "the collection" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Add a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: SamlApps::CreateRequest.as_schema } }

        response 201, "created; nobody can use it until it's assigned" do
          schema Schemas::SamlApp
        end

        response 422, "invalid settings" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps/parse-metadata" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      post "Read a SAML app's metadata into settings" do
        tags "SAML"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: SamlApps::ParseMetadataRequest.as_schema } }

        response 200, "the settings found; nothing is saved" do
          schema type: :object
        end

        response 422, "not SAML service provider metadata" do
          schema Schemas::Error
        end
      end
    end

    let(:collection) { "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps" }
    let(:body) do
      {
        name: "Wiki", entity_id: "https://wiki.example.com/saml", acs_urls: [ "https://wiki.example.com/saml/acs" ],
        attribute_mappings: [ { name: "mail", source: "email" }, { name: "role", source: "custom:role" } ]
      }
    end

    it "adds an app that developers can manage" do
      assert_api_response(:post, 201, headers: auth_headers_for(developer), body: body, path_params: project_path_params(project)) do
        expect(parsed_body).to include("entity_id" => "https://wiki.example.com/saml", "sign_assertion" => true)
        expect(parsed_body["launch_url"]).to end_with("/saml/apps/#{parsed_body['uid']}/launch")
      end
    end

    it "rejects plain http ACS URLs and unknown attribute sources" do
      assert_api_response(:post, 422, headers: auth_headers_for(admin), body: body.merge(acs_urls: [ "http://wiki.example.com/acs" ]), path_params: project_path_params(project), api_path: collection)
      assert_api_response(:post, 422, headers: auth_headers_for(admin), body: body.merge(attribute_mappings: [ { name: "x", source: "password" } ]), path_params: project_path_params(project), api_path: collection)
    end

    it "reads settings from the app's metadata" do
      assert_api_response(:post, 200, headers: auth_headers_for(admin), body: { metadata_xml: sp_metadata }, path_params: project_path_params(project)) do
        expect(parsed_body).to include(
          "entity_id" => "https://wiki.example.com/saml",
          "acs_urls" => [ "https://wiki.example.com/saml/acs", "https://wiki.example.com/saml/acs-2" ],
          "slo_url" => "https://wiki.example.com/saml/slo",
          "name_id_format" => "persistent"
        )
      end
    end

    it "fetches metadata from a URL" do
      stub_request(:get, "https://wiki.example.com/saml/metadata").to_return(status: 200, body: sp_metadata)

      assert_api_response(:post, 200, headers: auth_headers_for(admin), body: { metadata_url: "https://wiki.example.com/saml/metadata" }, path_params: project_path_params(project))
    end

    it "refuses documents with a document type" do
      evil = %(<?xml version="1.0"?><!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]>#{sp_metadata})

      assert_api_response(:post, 422, headers: auth_headers_for(admin), body: { metadata_xml: evil }, path_params: project_path_params(project), api_path: "#{collection}/parse-metadata")
    end
  end

  describe "the identity provider and its certificates" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-certificates" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }

      get "The project's SAML identity provider details and certificates" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 200, "entity ID, endpoints and certificates" do
          schema Schemas::SamlIdentityProvider
        end
      end

      post "Add the next signing certificate" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 201, "added and published, not yet used for signing"

        response 403, "only admins can rotate certificates" do
          schema Schemas::Error
        end
      end
    end

    let(:path_params) { project_path_params(project) }

    it "creates the first certificate on demand" do
      assert_api_response(:get, 200, headers: auth_headers_for(developer), path_params: path_params) do
        expect(parsed_body["entity_id"]).to eq("#{project.token_issuer}/saml/metadata")
        expect(parsed_body["certificates"].sole).to include("status" => "active")
      end
    end

    it "rotates: add the next certificate, activate it, then remove the retired one" do
      old = SamlCertificate.active_for!(project)
      assert_api_response(:post, 201, headers: auth_headers_for(admin), path_params: path_params)
      upcoming = project.saml_certificates.status_next.sole

      post "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/saml-certificates/#{upcoming.uid}/activate", headers: auth_headers_for(admin)
      expect(response).to have_http_status(:ok)
      expect(SamlCertificate.active_for!(project)).to eq(upcoming)

      delete "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/saml-certificates/#{upcoming.uid}", headers: auth_headers_for(admin)
      expect(response).to have_http_status(:conflict)
      delete "/v1/accounts/#{project.account.uid}/projects/#{project.uid}/saml-certificates/#{old.uid}", headers: auth_headers_for(admin)
      expect(response).to have_http_status(:no_content)
    end

    it "is only for admins to rotate" do
      assert_api_response(:post, 403, headers: auth_headers_for(developer), path_params: path_params)
    end
  end
end
