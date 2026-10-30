module SamlApps
  class CreateRequest < ApplicationRequestModel
    attribute :name, Fields::Name
    attribute :entity_id, Fields::EntityId
    attribute :acs_urls, Fields::AcsUrls
    attribute? :slo_url, Fields::SloUrl
    attribute? :sp_certificate, Fields::SpCertificate
    attribute? :name_id_format, Fields::NameIdFormat
    attribute? :attribute_mappings, Fields::AttributeMappings
    attribute? :sign_assertion, Fields::SignAssertion
    attribute? :sign_response, Fields::SignResponse
    attribute? :require_signed_requests, Fields::RequireSignedRequests
    attribute? :default_relay_state, Fields::DefaultRelayState
    attribute? :enabled, Fields::Enabled
  end
end
