module SamlIdp
  # A project's identity provider metadata, which SAML apps import.
  class Metadata
    # @param project [Project]
    def initialize(project)
      @project = project
    end

    # @return [String] the entity ID apps know the project by
    def entity_id
      "#{@project.token_issuer}/saml/metadata"
    end

    def sso_url
      "#{@project.token_issuer}/saml/sso"
    end

    def slo_url
      "#{@project.token_issuer}/saml/slo"
    end

    # @return [String] XML
    def to_xml
      SamlCertificate.active_for!(@project)
      certificates = @project.saml_certificates.published.order(:created_at)

      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml["md"].EntityDescriptor("xmlns:md" => Messages::NAMESPACES["md"], "xmlns:ds" => Messages::NAMESPACES["ds"], "entityID" => entity_id) do
          xml["md"].IDPSSODescriptor("protocolSupportEnumeration" => Messages::PROTOCOL, "WantAuthnRequestsSigned" => "false") do
            certificates.each do |certificate|
              xml["md"].KeyDescriptor("use" => "signing") do
                xml["ds"].KeyInfo { xml["ds"].X509Data { xml["ds"].X509Certificate(certificate.base64_der) } }
              end
            end
            [ Messages::REDIRECT_BINDING, Messages::POST_BINDING ].each { |binding| xml["md"].SingleLogoutService("Binding" => binding, "Location" => slo_url) }
            SamlApp::NAME_ID_FORMATS.each_value { |format| xml["md"].NameIDFormat(format) }
            [ Messages::REDIRECT_BINDING, Messages::POST_BINDING ].each { |binding| xml["md"].SingleSignOnService("Binding" => binding, "Location" => sso_url) }
          end
        end
      end.to_xml
    end
  end
end
