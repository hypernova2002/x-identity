class Schemas::SamlApp
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name enabled entity_id acs_urls slo_url sp_certificate name_id_format attribute_mappings sign_assertion
      sign_response require_signed_requests default_relay_state launch_url created_at updated_at],
    properties: {
      uid: { type: :string, example: "saml_9Lq3Wm7Xc2Vb8Nz4Rt6Kj5Hd" },
      name: { type: :string },
      enabled: { type: :boolean },
      entity_id: { type: :string },
      acs_urls: { type: :array, items: { type: :string } },
      slo_url: { type: [ :string, :null ] },
      sp_certificate: { type: [ :string, :null ] },
      name_id_format: { type: :string, enum: SamlApp::NAME_ID_FORMATS.keys },
      attribute_mappings: {
        type: :array,
        items: { type: :object, required: %w[name source], properties: { name: { type: :string }, source: { type: :string } } }
      },
      sign_assertion: { type: :boolean },
      sign_response: { type: :boolean },
      require_signed_requests: { type: :boolean },
      default_relay_state: { type: [ :string, :null ] },
      launch_url: { type: :string, description: "Starts an IdP-initiated sign-in." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
