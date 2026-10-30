module SamlApps
  # Field types shared by the SAML app requests.
  module Fields
    T = RequestTypes::T

    Name = RequestTypes::Name.meta(description: "The app's name.")
    EntityId = RequestTypes::SamlEntityId.meta(description: "The app's SAML entity ID (Issuer), unique in the project.")
    AcsUrls = T::Array.of(RequestTypes::Url).constrained(min_size: 1, max_size: SamlApp::MAX_ACS_URLS)
      .meta(description: "Assertion consumer service URLs, for the HTTP-POST binding. The first is used for IdP-initiated sign-in.")
    SloUrl = RequestTypes::Url.optional.meta(description: "The app's single logout URL, for the HTTP-Redirect binding; null if it has none.")
    SpCertificate = RequestTypes::Certificate.optional
      .meta(description: "The app's signing certificate (PEM), to verify its signed requests; null if it has none.")
    NameIdFormat = RequestTypes::SamlNameIdFormat
    AttributeMappings = T::Array.of(SamlApps::AttributeMapping).constrained(max_size: SamlApp::MAX_ATTRIBUTES)
      .meta(description: "Attributes sent in the assertion, each taken from a field of the end user.")
    SignAssertion = T::Bool.meta(description: "Sign the assertion.")
    SignResponse = T::Bool.meta(description: "Sign the whole response.")
    RequireSignedRequests = T::Bool.meta(description: "Reject authentication requests that aren't signed with the app's certificate.")
    DefaultRelayState = T::String.constrained(min_size: 1, max_size: 1024).optional
      .meta(description: "Sent with IdP-initiated sign-ins, e.g. the page to open in the app; null sends none.")
    Enabled = T::Bool.meta(description: "Disabled apps can't be signed in to.")

    MetadataXml = RequestTypes::SamlMetadataXml.meta(description: "The app's SAML metadata document.")
    MetadataUrl = RequestTypes::Url.meta(description: "The URL the app's SAML metadata is published at.")
  end
end
