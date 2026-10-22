class Schemas::AppAssignment
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid principal_type principal_uid principal_label created_at],
    properties: {
      uid: { type: :string, example: "asg_2Wq7Lm4Xc9Vb3Nz8Rt5Kj6Hd" },
      principal_type: { type: :string, enum: %w[end_user group] },
      principal_uid: { type: :string },
      principal_label: { type: :string, description: "The group's name or the end user's email." },
      created_at: { type: :string, format: "date-time" }
    }
  )
end
