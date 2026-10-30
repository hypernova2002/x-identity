module SamlApps
  class AttributeMapping < ApplicationRequestModel
    attribute :name, RequestTypes::T::String.constrained(min_size: 1, max_size: 255).meta(description: "The attribute name the app expects.")
    attribute :source, RequestTypes::T::String.constrained(min_size: 1, max_size: "custom:".length + EndUserAttributeDefinition::KEY_MAX_LENGTH)
      .meta(description: "email, email_verified, name, uid, groups, or custom:<attribute key>.")
  end
end
