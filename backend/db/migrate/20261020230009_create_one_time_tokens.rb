class CreateOneTimeTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :one_time_tokens do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :purpose, null: false
      t.string :token_digest, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :one_time_tokens, :token_digest, unique: true
    add_index :one_time_tokens, [ :subject_type, :subject_id, :purpose ]
  end
end
