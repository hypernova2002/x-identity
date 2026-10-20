class CreateProjectMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :project_memberships do |t|
      t.bigint :project_id, null: false
      t.bigint :user_id, null: false
      t.string :role, null: false
      t.timestamps
    end

    add_index :project_memberships, [ :project_id, :user_id ], unique: true
    add_index :project_memberships, :user_id
  end
end
