class CreateEndUserAttributeDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :end_user_attribute_definitions do |t|
      t.string :uid, null: false
      t.bigint :project_id, null: false
      t.string :key, null: false
      t.string :label, null: false
      t.string :data_type, null: false
      t.boolean :required, null: false, default: false
      t.integer :max_length
      t.boolean :user_editable, null: false, default: true
      t.boolean :include_in_token, null: false, default: false
      t.timestamps
    end

    add_index :end_user_attribute_definitions, :uid, unique: true
    add_index :end_user_attribute_definitions, [ :project_id, :key ], unique: true
  end
end
