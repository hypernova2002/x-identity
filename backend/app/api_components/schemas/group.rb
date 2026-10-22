class Schemas::Group
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name description default_for_new_users member_count created_at updated_at],
    properties: {
      uid: { type: :string, example: "grp_5Hk2Lq8Wm3Xn7Bv4Lc9Tz6Rp" },
      name: { type: :string },
      description: { type: [ :string, :null ] },
      default_for_new_users: { type: :boolean, description: "New end users join the group automatically." },
      member_count: { type: :integer },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
