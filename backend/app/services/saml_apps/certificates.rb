module SamlApps
  # Rotating a project's SAML signing certificate: add the next one (published in metadata straight
  # away, so apps can trust it ahead of time), make it active, and remove the old one later.
  class Certificates
    # @param actor [User]
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    def initialize(actor:, project:, ip: nil, user_agent: nil)
      @actor = actor
      @project = project
      @ip = ip
      @user_agent = user_agent
    end

    # @return [SamlCertificate]
    # @raise [ApiError] `conflict` when a next certificate already waits
    def add_next
      authorize!
      raise ApiError.new(:conflict, message: "A new certificate is already waiting to be activated.") if @project.saml_certificates.status_next.exists?

      SamlCertificate.transaction do
        SamlCertificate.active_for!(@project)
        SamlCertificate.generate!(project: @project, status: "next").tap { |certificate| record("saml_certificate.created", certificate) }
      end
    end

    # The current active certificate is retired but stays published until it's removed.
    # @param certificate [SamlCertificate]
    def activate(certificate)
      authorize!
      raise ApiError.new(:conflict, message: "Only a new certificate can be activated.") unless certificate.status_next?

      SamlCertificate.transaction do
        @project.saml_certificates.status_active.update_all(status: "retired")
        certificate.update!(status: "active", activated_at: Time.current)
        record("saml_certificate.activated", certificate)
      end
    end

    # @param certificate [SamlCertificate]
    def remove(certificate)
      authorize!
      raise ApiError.new(:conflict, message: "The active certificate can't be removed. Activate another one first.") if certificate.status_active?

      SamlCertificate.transaction do
        certificate.destroy!
        record("saml_certificate.deleted", certificate)
      end
    end

    private

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_settings?
    end

    def record(action, certificate)
      @project.realm.recorder(ip: @ip, user_agent: @user_agent).record(action: action, actor: @actor, target: certificate, metadata: { status: certificate.status })
    end
  end
end
