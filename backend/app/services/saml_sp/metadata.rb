module SamlSp
  # The project's service provider metadata for one upstream SAML provider, which the customer
  # imports into their identity provider.
  class Metadata
    # @param provider [IdentityProvider]
    def initialize(provider)
      @provider = provider
    end

    # @return [String] XML
    def to_xml
      namespaces = SamlIdp::Messages::NAMESPACES
      SamlCertificate.active_for!(@provider.project)

      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml["md"].EntityDescriptor("xmlns:md" => namespaces["md"], "xmlns:ds" => namespaces["ds"], "entityID" => @provider.sp_entity_id) do
          xml["md"].SPSSODescriptor("protocolSupportEnumeration" => SamlIdp::Messages::PROTOCOL, "AuthnRequestsSigned" => "true", "WantAssertionsSigned" => "true") do
            @provider.project.saml_certificates.published.order(:created_at).each do |certificate|
              xml["md"].KeyDescriptor("use" => "signing") do
                xml["ds"].KeyInfo { xml["ds"].X509Data { xml["ds"].X509Certificate(certificate.base64_der) } }
              end
            end
            [ SamlIdp::Messages::REDIRECT_BINDING, SamlIdp::Messages::POST_BINDING ].each do |binding|
              xml["md"].SingleLogoutService("Binding" => binding, "Location" => @provider.sp_slo_url)
            end
            xml["md"].NameIDFormat(SamlApp::NAME_ID_FORMATS.fetch(@provider.saml_name_id_format))
            xml["md"].AssertionConsumerService("Binding" => SamlIdp::Messages::POST_BINDING, "Location" => @provider.acs_url, "index" => "0", "isDefault" => "true")
          end
        end
      end.to_xml
    end
  end
end
