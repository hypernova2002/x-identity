class Schemas::DeviceSession
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid device_name device_type ip user_agent location amr created_at last_seen_at current],
    properties: {
      uid: { type: :string, example: "ses_9Lq3Wm7Xc2Vb8Nz4Rt6Kj5Hd" },
      device_name: { type: [ :string, :null ], description: "From the user agent, e.g. \"Chrome on macOS\"; null when unknown." },
      device_type: { type: [ :string, :null ], example: "desktop" },
      ip: { type: [ :string, :null ], description: "The device's most recent IP address." },
      user_agent: { type: [ :string, :null ] },
      location: {
        type: [ :object, :null ],
        description: "Approximate, from an offline IP database (DB-IP Lite, CC BY 4.0).",
        required: %w[city region country_code],
        properties: { city: { type: [ :string, :null ] }, region: { type: [ :string, :null ] }, country_code: { type: [ :string, :null ] } }
      },
      amr: { type: :array, items: { type: :string }, description: "How the user signed in, e.g. [\"pwd\", \"otp\"]." },
      created_at: { type: :string, format: "date-time", description: "When the device signed in." },
      last_seen_at: { type: :string, format: "date-time" },
      current: { type: :boolean, description: "The device making this request." }
    }
  )
end
