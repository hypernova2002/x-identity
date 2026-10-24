class Schemas::DeletedProject
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name deleted_at purge_at],
    properties: {
      uid: { type: :string },
      name: { type: :string },
      deleted_at: { type: :string, format: "date-time" },
      purge_at: { type: :string, format: "date-time", description: "When its data is permanently deleted; it can be restored until then." }
    }
  )
end
