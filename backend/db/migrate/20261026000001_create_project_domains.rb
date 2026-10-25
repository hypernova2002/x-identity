class CreateProjectDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :project_domains do |t|
      t.string :uid, null: false
      t.references :project, null: false, foreign_key: true, index: false
      t.string :hostname, null: false
      t.string :status, null: false
      t.string :verification_token, null: false
      t.datetime :verified_at
      t.datetime :last_checked_at
      t.integer :check_attempts, null: false, default: 0
      t.string :check_error
      t.datetime :dns_missing_since
      t.string :certificate_status, null: false
      t.timestamps
    end

    add_index :project_domains, :uid, unique: true
    add_index :project_domains, :hostname, unique: true
    # One domain in use and one being set up (e.g. its replacement) per project.
    add_index :project_domains, :project_id, unique: true, where: "status = 'verified'", name: "index_project_domains_one_verified"
    add_index :project_domains, :project_id, unique: true, where: "status <> 'verified'", name: "index_project_domains_one_unverified"
  end
end
