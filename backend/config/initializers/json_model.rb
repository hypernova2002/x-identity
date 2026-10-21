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
