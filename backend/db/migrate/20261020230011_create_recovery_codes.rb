class CreateRecoveryCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :recovery_codes do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :code_digest, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :recovery_codes, [ :subject_type, :subject_id ]
    add_index :recovery_codes, :code_digest
  end
end
