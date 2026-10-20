class Schemas::SignInResult
  include OpenapiRuby::Components::Base

  schema(oneOf: [ Schemas::TokenSet, Schemas::SignInChallenge ])
end
