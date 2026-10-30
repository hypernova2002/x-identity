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

      get "List the project's SAML apps" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 200, "SAML apps, by name" do
          schema type: :array, items: Schemas::SamlApp
        end
      end

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

    it "lists the project's apps" do
      create(:saml_app, project: project, name: "Wiki")
      create(:saml_app)

      assert_api_response(:get, 200, headers: auth_headers_for(developer), path_params: project_path_params(project), api_path: collection) do
        expect(parsed_body.pluck("name")).to eq([ "Wiki" ])
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

  describe "a SAML app" do
    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      get "Get a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 200, "the SAML app" do
          schema Schemas::SamlApp
        end

        response 404, "no such SAML app in the project" do
          schema Schemas::Error
        end
      end

      patch "Change a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: SamlApps::UpdateRequest.as_schema } }

        response 200, "updated" do
          schema Schemas::SamlApp
        end

        response 403, "only project admins and developers can manage SAML apps" do
          schema Schemas::Error
        end

        response 422, "invalid settings" do
          schema Schemas::Error
        end
      end

      delete "Delete a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 204, "deleted"
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps/{saml_app_uid}/assignments" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :saml_app_uid, in: :path, required: true, schema: { type: :string }

      get "List who can use a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 200, "assignments" do
          schema type: :array, items: Schemas::AppAssignment
        end
      end

      post "Give an end user or group access to a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]
        consumes "application/json"
        request_body required: true, content: { "application/json" => { schema: AppAssignments::CreateRequest.as_schema } }

        response 201, "assigned" do
          schema Schemas::AppAssignment
        end

        response 404, "no such end user or group in the project" do
          schema Schemas::Error
        end

        response 409, "already assigned" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps/{saml_app_uid}/assignments/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :saml_app_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Take away an end user's or group's access to a SAML app" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 204, "removed"

        response 404, "no such assignment" do
          schema Schemas::Error
        end
      end
    end

    let(:saml_app) { create(:saml_app, project: project, name: "Wiki", assigned_to_everyone: false) }
    let(:viewer) { create(:user, account: project.account).tap { |user| create(:project_membership, project: project, user: user, role: "viewer") } }
    let(:item_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps/{uid}" }
    let(:assignments_path) { "/v1/accounts/{account_uid}/projects/{project_uid}/saml-apps/{saml_app_uid}/assignments" }

    it "shows, changes and deletes an app" do
      path_params = project_path_params(project, uid: saml_app.uid)

      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params, api_path: item_path) do
        expect(parsed_body).to include("uid" => saml_app.uid, "name" => "Wiki")
      end
      assert_api_response(:patch, 200, headers: auth_headers_for(developer), body: { name: "Team wiki", sign_response: true }, path_params: path_params,
        api_path: item_path) do
        expect(parsed_body).to include("name" => "Team wiki", "sign_response" => true)
      end
      assert_api_response :delete, 204, headers: auth_headers_for(developer), path_params: path_params, api_path: item_path

      expect(SamlApp.exists?(saml_app.id)).to be(false)
    end

    it "doesn't let viewers change apps" do
      assert_api_response :patch, 403, headers: auth_headers_for(viewer), body: { name: "Team wiki" }, path_params: project_path_params(project, uid: saml_app.uid),
        api_path: item_path
    end

    it "rejects plain http ACS URLs" do
      assert_api_response :patch, 422, headers: auth_headers_for(admin), body: { acs_urls: [ "http://wiki.example.com/acs" ] },
        path_params: project_path_params(project, uid: saml_app.uid), api_path: item_path
    end

    it "doesn't show apps of other projects" do
      assert_api_response :get, 404, headers: auth_headers_for(admin), path_params: project_path_params(project, uid: create(:saml_app).uid), api_path: item_path
    end

    it "assigns end users and groups, and removes assignments" do
      group = create(:group, project: project, name: "Staff")
      path_params = project_path_params(project, saml_app_uid: saml_app.uid)
      body = { principal_type: "group", principal_uid: group.uid }
      uid = nil

      assert_api_response(:post, 201, headers: auth_headers_for(admin), body: body, path_params: path_params, api_path: assignments_path) do
        uid = parsed_body["uid"]
        expect(parsed_body).to include("principal_type" => "group", "principal_label" => "Staff")
      end
      assert_api_response :post, 409, headers: auth_headers_for(admin), body: body, path_params: path_params, api_path: assignments_path
      assert_api_response :post, 404, headers: auth_headers_for(admin), body: { principal_type: "end_user", principal_uid: create(:end_user).uid },
        path_params: path_params, api_path: assignments_path
      assert_api_response(:get, 200, headers: auth_headers_for(viewer), path_params: path_params, api_path: assignments_path) do
        expect(parsed_body.pluck("uid")).to eq([ uid ])
      end

      assignment_path = "#{assignments_path}/{uid}"
      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params.merge(uid: uid), api_path: assignment_path
      assert_api_response :delete, 404, headers: auth_headers_for(admin), path_params: path_params.merge(uid: uid), api_path: assignment_path
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

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-certificates/{uid}" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      delete "Remove a certificate that isn't active" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 204, "removed and no longer published"

        response 409, "the active certificate can't be removed" do
          schema Schemas::Error
        end
      end
    end

    api_path "/v1/accounts/{account_uid}/projects/{project_uid}/saml-certificates/{uid}/activate" do
      parameter name: :account_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :project_uid, in: :path, required: true, schema: { type: :string }
      parameter name: :uid, in: :path, required: true, schema: { type: :string }

      post "Start signing with the next certificate" do
        tags "SAML"
        security [ { BearerAuth: [] } ]

        response 200, "active; the previous certificate is retired" do
          schema Schemas::SamlCertificate
        end

        response 409, "only a new certificate can be activated" do
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

      certificate_path = "/v1/accounts/{account_uid}/projects/{project_uid}/saml-certificates/{uid}"
      assert_api_response(:post, 200, headers: auth_headers_for(admin), path_params: path_params.merge(uid: upcoming.uid), api_path: "#{certificate_path}/activate") do
        expect(parsed_body).to include("uid" => upcoming.uid, "status" => "active")
      end
      expect(SamlCertificate.active_for!(project)).to eq(upcoming)
      assert_api_response :post, 409, headers: auth_headers_for(admin), path_params: path_params.merge(uid: old.uid), api_path: "#{certificate_path}/activate"

      assert_api_response :delete, 409, headers: auth_headers_for(admin), path_params: path_params.merge(uid: upcoming.uid), api_path: certificate_path
      assert_api_response :delete, 204, headers: auth_headers_for(admin), path_params: path_params.merge(uid: old.uid), api_path: certificate_path
    end

    it "is only for admins to rotate" do
      assert_api_response(:post, 403, headers: auth_headers_for(developer), path_params: path_params)
    end
  end
end
