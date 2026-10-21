# Field types shared by request models, constrained to the limits the models enforce.
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
    .constructor(NORMALIZE_EMAIL)
  EmailLookup = T::String.constrained(min_size: 1, max_size: 254).constructor(NORMALIZE_EMAIL)
  Password = T::String.constrained(min_size: 1, max_size: AuthConfiguration::PASSWORD_MAX_LENGTH)
  Name = T::String.constrained(min_size: 1, max_size: 100)
  Uid = T::String.constrained(min_size: 1, max_size: 64)
  Token = T::String.constrained(min_size: 1, max_size: 256)
  OtpCode = T::String.constrained(min_size: 1, max_size: 32).meta(description: "A TOTP code or an unused recovery code.")
  EmailCode = T::String.constrained(min_size: 6, max_size: 6, format: /^\d{6}$/).meta(description: "The 6-digit code from the email.")
  OtpType = T::String.enum(*AuthConfiguration::OTP_METHODS)
    .meta(description: "totp for authenticator apps, hotp for hardware tokens. Defaults to the first method allowed.")
  AccountRole = T::String.enum(*User.roles.keys)
  ProjectRole = T::String.enum(*ProjectMembership.roles.keys)

  Origins = T::Array.of(T::String.constrained(max_size: 255)).constrained(max_size: AppClient::MAX_ORIGINS)
    .meta(description: "Browser origins allowed to call the API, e.g. https://shop.example.com.")
  AttributeMaxLength = T::Integer.constrained(gteq: 1, lteq: EndUserAttributeDefinition::MAX_STRING_LENGTH).optional
    .meta(description: "String attributes only.")

  # Keys are defined per project by admins, so they can't be declared as a nested request model;
  # values are checked against the project's attribute definitions by EndUsers::AttributeValidator.
  CustomAttributes = T::Hash.meta(description: "Values for the project's custom attributes, keyed by attribute key.")
end
