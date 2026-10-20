class SecuritySchemes::BearerAuth
  include OpenapiRuby::Components::Base

  component_type :securitySchemes

  schema(
    type: :http,
    scheme: :bearer,
    bearerFormat: "JWT"
  )
end
