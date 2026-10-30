# json_model_rb 0.1.30 has no schema builder for free-form objects (a Dry `Hash` type without a
# declared schema, such as passkey extension results) or for maps (`Hash.map`, such as custom
# attributes). Document them as objects, with a map's key and value types.
module FreeFormObjectSchema
  class ObjectBuilder < JsonModel::Builder::BaseBuilder
    def as_schema
      { type: "object" }
    end
  end

  class MapBuilder < JsonModel::Builder::BaseBuilder
    def as_schema
      {
        type: "object",
        propertyNames: JsonModel::Builder.for(type.key_type).as_schema.except(:type),
        additionalProperties: JsonModel::Builder.for(type.value_type).as_schema
      }
    end
  end

  def for(type)
    return MapBuilder.new(type) if type.is_a?(Dry::Types::Map)

    free_form = type.is_a?(Dry::Types::Hash) && !type.is_a?(Dry::Types::Schema)
    return ObjectBuilder.new(type) if free_form

    super
  end
end

JsonModel::Builder.singleton_class.prepend(FreeFormObjectSchema)

# json_model_rb 0.1.30 drops every constraint of a type with a `format`, such as an email's length
# limits. Keep them, leaving out only the pattern, which the format already describes.
module FormatConstraints
  def as_schema
    return super unless type.meta[:format]

    super.merge(*extract_constraints.reject { |constraint| constraint.key?(:pattern) })
  end
end

JsonModel::Builder::ConstrainedBuilder.prepend(FormatConstraints)

# json_model_rb 0.1.30 documents a hash's size limits as a string's (`maxLength`). Name them as an
# object's.
module ObjectSizeConstraints
  OBJECT_KEYS = { maxLength: :maxProperties, minLength: :minProperties }.freeze

  def as_schema
    return super unless type.primitive == ::Hash

    super.transform_keys { |key| OBJECT_KEYS.fetch(key, key) }
  end
end

JsonModel::Builder::ConstrainedBuilder.prepend(ObjectSizeConstraints)
