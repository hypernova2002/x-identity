class AddCodesToOneTimeTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :one_time_tokens, :code_digest, :string
    add_column :one_time_tokens, :failed_attempts, :integer, null: false, default: 0
  end
end
