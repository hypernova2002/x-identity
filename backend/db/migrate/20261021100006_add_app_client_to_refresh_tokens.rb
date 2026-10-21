class AddAppClientToRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :refresh_tokens, :app_client_id, :bigint
    add_index :refresh_tokens, :app_client_id
  end
end
