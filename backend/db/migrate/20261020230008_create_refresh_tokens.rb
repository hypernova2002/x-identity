class CreateRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :refresh_tokens do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :token_digest, null: false
      t.string :family_id, null: false
      t.datetime :authenticated_at, null: false
      t.jsonb :amr, null: false, default: []
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :refresh_tokens, :token_digest, unique: true
    add_index :refresh_tokens, :family_id
    add_index :refresh_tokens, [ :subject_type, :subject_id ]
  end
end
