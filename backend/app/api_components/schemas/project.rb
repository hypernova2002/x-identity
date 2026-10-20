class Schemas::Project
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name created_at updated_at],
    properties: {
      uid: { type: :string, example: "proj_9Fk2Lm8Qw3Rt7Yx5Vb1Nc4D" },
      name: { type: :string },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
