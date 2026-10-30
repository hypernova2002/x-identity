class AddLocaleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :locale, :string
    add_column :end_users, :locale, :string
  end
end
