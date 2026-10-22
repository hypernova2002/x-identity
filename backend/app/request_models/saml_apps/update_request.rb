module SamlApps
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
    attribute? :entity_id, RequestTypes::T::String.constrained(min_size: 1, max_size: 1024).meta(description: "The app's SAML entity ID (Issuer).")
    attribute? :acs_urls, RequestTypes::T::Array.of(RequestTypes::T::String.constrained(max_size: 2048)).constrained(min_size: 1, max_size: SamlApp::MAX_ACS_URLS)
      .meta(description: "Assertion consumer service URLs, for the HTTP-POST binding. The first is used for IdP-initiated sign-in.")
    attribute? :slo_url, RequestTypes::T::String.constrained(max_size: 2048).optional.meta(description: "The app's single logout URL, for the HTTP-Redirect binding.")
    attribute? :sp_certificate, RequestTypes::T::String.constrained(max_size: 10_000).optional
      .meta(description: "The app's signing certificate (PEM), to verify its signed requests.")
    attribute? :name_id_format, RequestTypes::T::String.enum(*SamlApp::NAME_ID_FORMATS.keys)
    attribute? :attribute_mappings, RequestTypes::T::Array.of(SamlApps::AttributeMapping).constrained(max_size: SamlApp::MAX_ATTRIBUTES)
    attribute? :sign_assertion, RequestTypes::T::Bool
    attribute? :sign_response, RequestTypes::T::Bool
    attribute? :require_signed_requests, RequestTypes::T::Bool
    attribute? :default_relay_state, RequestTypes::T::String.constrained(max_size: 1024).optional
      .meta(description: "Sent with IdP-initiated sign-ins, e.g. the page to open in the app.")
    attribute? :enabled, RequestTypes::T::Bool
  end
end
