module SamlIdp
  # Reads a SAML app's own metadata into the settings a {SamlApp} needs.
  module SpMetadata
    module_function

    # @param xml [String]
    # @return [Hash{Symbol => Object}] entity_id, acs_urls, slo_url, sp_certificate and name_id_format, where found
    # @raise [ApiError] `validation_failed` on `metadata`
    def parse(xml)
      document = Messages.parse(xml.to_s)
      descriptor = document.at_xpath("//md:EntityDescriptor[md:SPSSODescriptor]", Messages::NAMESPACES)
      sp = descriptor&.at_xpath("md:SPSSODescriptor", Messages::NAMESPACES)
      raise ApiError.validation(:metadata, :no_saml_service_provider) unless sp

      {
        entity_id: descriptor["entityID"],
        acs_urls: acs_urls(sp),
        slo_url: sp.at_xpath("md:SingleLogoutService[@Binding='#{Messages::REDIRECT_BINDING}']", Messages::NAMESPACES)&.[]("Location"),
        sp_certificate: certificate(sp),
        name_id_format: name_id_format(sp)
      }.compact
    rescue Messages::Error => error
      raise ApiError.validation(:metadata, :unreadable_saml_metadata, reason: error.message)
    end

    def acs_urls(sp)
      services = sp.xpath("md:AssertionConsumerService[@Binding='#{Messages::POST_BINDING}']", Messages::NAMESPACES)
      services.sort_by { |service| [ service["isDefault"] == "true" ? 0 : 1, service["index"].to_i ] }.filter_map { |service| service["Location"] }.uniq
    end

    def certificate(sp)
      base64 = sp.at_xpath("md:KeyDescriptor[not(@use) or @use='signing']//ds:X509Certificate", Messages::NAMESPACES)&.text
      return nil if base64.blank?

      OpenSSL::X509::Certificate.new(Base64.decode64(base64.gsub(/\s+/, ""))).to_pem
    rescue OpenSSL::X509::CertificateError
      nil
    end

    def name_id_format(sp)
      formats = sp.xpath("md:NameIDFormat", Messages::NAMESPACES).map { |node| node.text.strip }
      SamlApp::NAME_ID_FORMATS.key(formats.find { |format| SamlApp::NAME_ID_FORMATS.value?(format) })
    end
  end
end
