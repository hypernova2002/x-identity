module SamlApps
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, Fields::Name
    attribute? :entity_id, Fields::EntityId
    attribute? :acs_urls, Fields::AcsUrls
    attribute? :slo_url, Fields::SloUrl
    attribute? :sp_certificate, Fields::SpCertificate
    attribute? :name_id_format, Fields::NameIdFormat
    attribute? :attribute_mappings, Fields::AttributeMappings
    attribute? :sign_assertion, Fields::SignAssertion
    attribute? :sign_response, Fields::SignResponse
    attribute? :require_signed_requests, Fields::RequireSignedRequests
    attribute? :default_relay_state, Fields::DefaultRelayState
    attribute? :enabled, Fields::Enabled
    attribute? :on_custom_domain, RequestTypes::T::Bool
      .meta(description: "Use the project's verified custom domain for this app's entity ID and URLs. Re-import the metadata in the app after switching.")
  end
end
