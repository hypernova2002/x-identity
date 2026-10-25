module V1
  module Accounts
    module Projects
      # The project's SAML identity provider details, and rotating its signing certificate.
      class SamlCertificatesController < ConsoleController
        before_action :set_certificate, only: %i[activate destroy]

        def index
          ::SamlCertificate.active_for!(current_project)
          metadata = ::SamlIdp::Metadata.new(current_project)
          render json: {
            entity_id: metadata.entity_id,
            metadata_url: metadata.entity_id,
            sso_url: metadata.sso_url,
            slo_url: metadata.slo_url,
            certificates: SamlCertificateSerializer.new(current_project.saml_certificates.order(:created_at)).serializable_hash
          }
        end

        def create
          render json: SamlCertificateSerializer.new(certificates.add_next).serializable_hash, status: :created
        end

        def activate
          certificates.activate(@certificate)
          render json: SamlCertificateSerializer.new(@certificate).serializable_hash
        end

        def destroy
          certificates.remove(@certificate)
          head :no_content
        end

        private

        def set_certificate
          @certificate = current_project.saml_certificates.find_by_uid!(params[:uid])
        end

        def certificates
          ::SamlApps::Certificates.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
