module IdentityProviders
  # Field types shared by the identity provider requests.
  module Fields
    T = RequestTypes::T

    Kind = T::String.enum(*IdentityProvider.kinds.values)
      .meta(description: "google, apple, oidc for any other OpenID Connect provider, or saml. Can't be changed later.")
    Name = RequestTypes::Name.meta(description: "Shown to end users, e.g. on sign-in buttons.")
    ClientId = T::String.constrained(min_size: 1, max_size: 255)
      .meta(description: "The client id registered with the provider. For Apple, the Services ID.")
    AdditionalAudiences = T::Array.of(T::String.constrained(min_size: 1, max_size: 255)).constrained(max_size: IdentityProvider::MAX_AUDIENCES)
      .meta(description: "Client ids of native apps that send the provider's ID tokens directly, e.g. iOS and Android client ids or an app's bundle id.")
    Scopes = T::String.constrained(min_size: 1, max_size: 500)
      .meta(description: "Space-separated; must include openid. Ignored for Apple, which always asks for name and email.")
    ClientSecret = T::String.constrained(min_size: 1, max_size: 1000).meta(description: "Google and OIDC only. Write-only.")
    ReplacementClientSecret = T::String.constrained(max_size: 1000)
      .meta(description: "Google and OIDC only. Write-only; blank keeps the current one.")
    DiscoveryUrl = RequestTypes::Url.meta(description: "OIDC only: the issuer URL, or its /.well-known/openid-configuration URL.")
    AppleId = T::String.constrained(min_size: 10, max_size: 10)
    AppleTeamId = AppleId.meta(description: "Apple only: the 10-character team ID.")
    AppleKeyId = AppleId.meta(description: "Apple only: the 10-character ID of the sign-in key.")
    ApplePrivateKey = T::String.constrained(min_size: 1, max_size: 4000)
      .meta(description: "Apple only: the .p8 key's contents, in PEM format. Write-only.")
    ReplacementApplePrivateKey = T::String.constrained(max_size: 4000)
      .meta(description: "Apple only: the .p8 key's contents, in PEM format. Write-only; blank keeps the current one.")

    SamlIdpEntityId = RequestTypes::SamlEntityId.meta(description: "SAML only: the IdP's entity ID.")
    SamlSsoUrl = RequestTypes::Url.meta(description: "SAML only: the IdP's sign-on URL (HTTP-Redirect).")
    SamlSloUrl = RequestTypes::Url.optional.meta(description: "SAML only: the IdP's logout URL (HTTP-Redirect); null if it has none.")
    SamlIdpCertificates = T::Array.of(RequestTypes::Certificate).constrained(max_size: IdentityProvider::MAX_CERTIFICATES)
      .meta(description: "SAML only: the IdP's signing certificates (PEM).")
    SamlNameIdFormat = RequestTypes::SamlNameIdFormat
    SamlAttribute = T::String.constrained(min_size: 1, max_size: 255).optional
    SamlEmailAttribute = SamlAttribute.meta(description: "SAML only: the attribute with the email; null uses the NameID.")
    SamlNameAttribute = SamlAttribute.meta(description: "SAML only: the attribute with the user's name; null if the IdP sends none.")
    SamlGroupsAttribute = SamlAttribute.meta(description: "SAML only: the attribute with the user's groups, for group mappings; null if the IdP sends none.")

    Domains = T::Array.of(RequestTypes::Hostname).constrained(max_size: IdentityProvider::MAX_DOMAINS)
      .meta(description: "Email domains the provider is authoritative for. SAML providers only sign in addresses at these domains, and users who enter them are sent to the provider.")
    CreateUsers = T::Bool.meta(description: "Create end users on their first sign-in, even when self sign-up is off.")
    AllowIdpInitiated = T::Bool.meta(description: "SAML only: accept sign-ins started from the provider, landing on the app portal.")
    GroupMappings = T::Array.of(IdentityProviders::GroupMappingRequest).constrained(max_size: 100)
      .meta(description: "Provider group values mapped to project groups. Replaces the current mappings.")
    Enabled = T::Bool.meta(description: "Disabled providers can't be used to sign in.")

    MetadataXml = RequestTypes::SamlMetadataXml.meta(description: "The IdP's SAML metadata document.")
    MetadataUrl = RequestTypes::Url.meta(description: "The URL the IdP's SAML metadata is published at.")
  end
end
