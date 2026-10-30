# json_model_rb 0.1.30 has no schema builder for free-form objects (a Dry `Hash` type without a
# declared schema), which custom attribute values need. Document them as `{ "type": "object" }`.
module FreeFormObjectSchema
  class ObjectBuilder < JsonModel::Builder::BaseBuilder
    def as_schema
      { type: "object" }
    end
  end

  def for(type)
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
