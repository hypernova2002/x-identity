module AttributeDefinitions
  # Field types shared by the attribute definition requests.
  module Fields
    T = RequestTypes::T

    Label = RequestTypes::Name.meta(description: "The attribute's name, shown in the console and to end users.")
    Required = T::Bool.meta(description: "Every end user must have a value.")
    MaxLength = T::Integer.constrained(gteq: 1, lteq: EndUserAttributeDefinition::MAX_STRING_LENGTH).optional
      .meta(description: "String attributes only: the longest value allowed. null allows up to #{EndUserAttributeDefinition::MAX_STRING_LENGTH} characters.")
    UserEditable = T::Bool.meta(description: "End users can set and change the value themselves.")
    IncludeInToken = T::Bool.meta(description: "The value is included in the end user's tokens.")
  end
end
