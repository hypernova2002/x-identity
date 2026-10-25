module Domains
  # Checks a domain's DNS: a TXT record with its verification token, and a CNAME pointing at
  # x-identity. A pending domain becomes verified, replacing the project's previous domain, or
  # failed once {ProjectDomain::VERIFY_FOR} has passed. A verified domain stays verified, but is
  # flagged while its records are missing.
  class Verification
    # @param domain [ProjectDomain]
    # @param resolver [DnsResolver]
    def initialize(domain, resolver: DnsResolver.new)
      @domain = domain
      @resolver = resolver
    end

    # @return [ProjectDomain]
    def call
      problem = problem_with_records
      @domain.assign_attributes(last_checked_at: Time.current, check_attempts: @domain.check_attempts + 1, check_error: problem)

      if @domain.status_verified?
        @domain.update!(dns_missing_since: problem ? (@domain.dns_missing_since || Time.current) : nil)
      elsif problem.nil?
        verify!
      elsif @domain.status_pending? && @domain.verify_until.past?
        @domain.update!(status: "failed")
        record("domain.failed", @domain, error: problem)
      else
        @domain.save!
      end
      @domain
    end

    private

    def problem_with_records
      return nil if @domain.local? && !Rails.env.production?

      unless Array(@resolver.txt(@domain.txt_record_name)).include?(@domain.verification_token)
        return "No TXT record #{@domain.txt_record_name} with the verification value was found."
      end

      cname = @resolver.cname(@domain.hostname)
      return nil if cname == @domain.cname_target

      cname ? "#{@domain.hostname} points to #{cname} instead of #{@domain.cname_target}." : "No CNAME record for #{@domain.hostname} was found."
    end

    def verify!
      replaced = @domain.project.domains.status_verified.where.not(id: @domain.id).to_a
      ProjectDomain.transaction do
        replaced.each(&:destroy!)
        @domain.update!(status: "verified", verified_at: Time.current, dns_missing_since: nil, certificate_status: Certificates.status_for(@domain))
      end
      replaced.each { |old| record("domain.removed", old, replaced_by: @domain.hostname) }
      record("domain.verified", @domain)
    end

    def record(action, domain, **metadata)
      domain.project.realm.recorder.record(action: action, target: domain, metadata: { hostname: domain.hostname, **metadata })
    end
  end
end
