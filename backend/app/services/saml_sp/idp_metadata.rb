module SamlSp
  # Reads an upstream identity provider's SAML metadata into provider settings.
  module IdpMetadata
    module_function

    # @param xml [String]
    # @return [Hash{Symbol => Object}] saml_idp_entity_id, saml_sso_url, saml_slo_url and saml_idp_certificates, where found
    # @raise [ApiError] `validation_failed` on `metadata`
    def parse(xml)
      namespaces = SamlIdp::Messages::NAMESPACES
      document = SamlIdp::Messages.parse(xml.to_s)
      descriptor = document.at_xpath("//md:EntityDescriptor[md:IDPSSODescriptor]", namespaces)
      idp = descriptor&.at_xpath("md:IDPSSODescriptor", namespaces)
      raise ApiError.validation(:metadata, :no_saml_identity_provider) unless idp

      sso = idp.at_xpath("md:SingleSignOnService[@Binding='#{SamlIdp::Messages::REDIRECT_BINDING}']", namespaces)
      raise ApiError.validation(:metadata, :no_redirect_sso_url) unless sso

      {
        saml_idp_entity_id: descriptor["entityID"],
        saml_sso_url: sso["Location"],
        saml_slo_url: idp.at_xpath("md:SingleLogoutService[@Binding='#{SamlIdp::Messages::REDIRECT_BINDING}']", namespaces)&.[]("Location"),
        saml_idp_certificates: certificates(idp, namespaces)
      }.compact
    rescue SamlIdp::Messages::Error => error
      raise ApiError.validation(:metadata, :unreadable_saml_metadata, reason: error.message)
    end

    def certificates(idp, namespaces)
      idp.xpath("md:KeyDescriptor[not(@use) or @use='signing']//ds:X509Certificate", namespaces).filter_map do |node|
        OpenSSL::X509::Certificate.new(Base64.decode64(node.text.gsub(/\s+/, ""))).to_pem
      rescue OpenSSL::X509::CertificateError
        nil
      end.uniq.first(IdentityProvider::MAX_CERTIFICATES)
    end
  end
end
