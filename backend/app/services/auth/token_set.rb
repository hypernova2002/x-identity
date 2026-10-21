module Auth
  # `id_token` is only issued to end users, through an app client.
  TokenSet = Data.define(:access_token, :refresh_token, :expires_in, :id_token) do
    def initialize(access_token:, refresh_token:, expires_in:, id_token: nil)
      super
    end

    def token_type
      "Bearer"
    end
  end
end
