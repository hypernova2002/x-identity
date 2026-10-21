class Schemas::AppClientWithSecret < Schemas::AppClient
  schema(
    properties: {
      client_secret: { type: [ :string, :null ], description: "Confidential clients only. Shown once; store it securely." }
    }
  )
end
