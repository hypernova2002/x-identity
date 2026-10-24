class AddDeletedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :deleted_at, :datetime
  end
end
