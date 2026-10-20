module Auth
  TokenSet = Data.define(:access_token, :refresh_token, :expires_in) do
    def token_type
      "Bearer"
    end
  end
end
