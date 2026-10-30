# Field types shared by request models of more than one resource, constrained to the limits the
# models enforce. Types used by one resource live in that resource's Fields module.
#
# Patterns end up in the OpenAPI document, where Ruby's \A and \z anchors aren't valid, so they use
# ^ and $. In Ruby those match at line breaks, so every pattern is paired with a length limit, and
# models re-validate with strict anchors.
module RequestTypes
  T = JsonModel::Types

  # Email addresses are normalised (see EmailAddress) as they're parsed, so services always receive
  # the canonical form. Non-strings are passed through untouched so they fail the type check.
  NORMALIZE_EMAIL = ->(value) { value.is_a?(String) ? EmailAddress.normalize(value) : value }
  Email = T::String.constrained(min_size: 3, max_size: 254, format: URI::MailTo::EMAIL_REGEXP).meta(format: "email")
    .meta(description: "An email address. Stored in lowercase.").constructor(NORMALIZE_EMAIL)
  EmailLookup = T::String.constrained(min_size: 1, max_size: 254).meta(description: "The email address, in any case.")
    .constructor(NORMALIZE_EMAIL)
  Password = T::String.constrained(min_size: 1, max_size: AuthConfiguration::PASSWORD_MAX_LENGTH).meta(description: "The password.")
  Name = T::String.constrained(min_size: 1, max_size: 100).meta(description: "A display name.")
  Uid = T::String.constrained(min_size: 1, max_size: 64)
  Token = T::String.constrained(min_size: 1, max_size: 256)
  OtpCode = T::String.constrained(min_size: 1, max_size: 32).meta(description: "A TOTP code or an unused recovery code.")
  EmailCode = T::String.constrained(min_size: 6, max_size: 6, format: /^\d{6}$/).meta(description: "The 6-digit code from the email.")
  Jwt = T::String.constrained(min_size: 1, max_size: 16_384)
  AccountRole = T::String.enum(*User.roles.keys).meta(description: "The user's role in the account.")
  ProjectRole = T::String.enum(*ProjectMembership.roles.keys).meta(description: "The user's role in the project.")

  Url = T::String.constrained(min_size: 1, max_size: WebUrl::MAX_LENGTH)
  Hostname = T::String.constrained(min_size: 1, max_size: 253)
  SamlEntityId = T::String.constrained(min_size: 1, max_size: 1024)
  SamlNameIdFormat = T::String.enum(*SamlApp::NAME_ID_FORMATS.keys).meta(description: "The format of the NameID: #{SamlApp::NAME_ID_FORMATS.keys.join(', ')}.")
  SamlMetadataXml = T::String.constrained(min_size: 1, max_size: 256_000)
  Certificate = T::String.constrained(min_size: 1, max_size: 10_000)
  ScopeName = T::String.constrained(min_size: 1, max_size: 64)
  TokenRequestsPerMinute = T::Integer.constrained(gteq: AuthConfiguration::TOKEN_REQUESTS_PER_MINUTE.min, lteq: AuthConfiguration::TOKEN_REQUESTS_PER_MINUTE.max)

  # Keys are defined per project by admins, so they can't be declared as a nested request model;
  # values are checked against the project's attribute definitions by EndUsers::AttributeValidator.
  CustomAttributes = T::Hash.meta(description: "Values for the project's custom attributes, keyed by attribute key.")
end
