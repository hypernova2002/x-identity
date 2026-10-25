class AddIssuerToRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    # Set when tokens were issued on a custom domain, so refreshes keep the same `iss`. Null is the standard issuer.
    add_column :refresh_tokens, :issuer, :string
  end
end
