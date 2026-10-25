class ProjectDomainSerializer
  include Alba::Resource

  attributes :uid, :hostname, :status, :verified_at, :last_checked_at, :check_error, :dns_missing_since, :certificate_status, :verify_until, :created_at
  attribute(:dns_records) do |domain|
    [
      { type: "CNAME", name: domain.hostname, value: domain.cname_target },
      { type: "TXT", name: domain.txt_record_name, value: domain.verification_token }
    ]
  end
end
