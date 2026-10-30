class StoreDomainCheckErrorsAsCodes < ActiveRecord::Migration[8.1]
  # The English messages the DNS check stored before, and the code each becomes.
  PATTERNS = {
    /\ANo TXT record (?<name>\S+) with the verification value was found\.\z/ => "missing_txt_record",
    /\A(?<hostname>\S+) points to (?<found>\S+) instead of (?<target>\S+)\.\z/ => "cname_mismatch",
    /\ANo CNAME record for (?<hostname>\S+) was found\.\z/ => "missing_cname"
  }.freeze

  def up
    add_column :project_domains, :check_error_params, :jsonb, null: false, default: {}

    select_rows("SELECT id, check_error FROM project_domains WHERE check_error IS NOT NULL").each do |id, message|
      pattern, code = PATTERNS.find { |candidate, _code| candidate.match?(message) }
      params = pattern ? pattern.match(message).named_captures : {}
      execute(sanitize_sql([ "UPDATE project_domains SET check_error = ?, check_error_params = ? WHERE id = ?", code || "unknown", params.to_json, id ]))
    end
  end

  def down
    remove_column :project_domains, :check_error_params
  end

  private

  def sanitize_sql(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
