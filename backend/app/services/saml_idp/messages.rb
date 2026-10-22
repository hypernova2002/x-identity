module SamlIdp
  # Encoding, decoding and signing SAML protocol messages for the HTTP-Redirect and HTTP-POST
  # bindings. XML is parsed without network access or entity expansion, and with a size limit.
  module Messages
    PROTOCOL = "urn:oasis:names:tc:SAML:2.0:protocol".freeze
    ASSERTION = "urn:oasis:names:tc:SAML:2.0:assertion".freeze
    NAMESPACES = { "samlp" => PROTOCOL, "saml" => ASSERTION, "md" => "urn:oasis:names:tc:SAML:2.0:metadata", "ds" => XMLSecurity::Document::DSIG }.freeze
    REDIRECT_BINDING = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect".freeze
    POST_BINDING = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST".freeze
    SIGNATURE_METHOD = XMLSecurity::Document::RSA_SHA256
    DIGEST_METHOD = XMLSecurity::Document::SHA256
    MAX_BYTES = 256.kilobytes

    Error = Class.new(StandardError)

    module_function

    # @param value [String] a base64 message, deflated for the Redirect binding
    # @param deflated [Boolean]
    # @return [Array(Nokogiri::XML::Document, String)] the parsed message and its XML as received,
    #   which embedded signatures are checked against
    # @raise [Error]
    def decode(value, deflated:)
      raise Error, "The SAML message is missing." if value.blank?

      raw = Base64.decode64(value)
      xml = deflated ? inflate(raw) : raw
      [ parse(xml), xml ]
    rescue Zlib::Error
      raise Error, "The SAML message isn't deflated correctly."
    end

    # @param xml [String]
    # @return [Nokogiri::XML::Document]
    # @raise [Error]
    def parse(xml)
      raise Error, "The SAML message is too large." if xml.bytesize > MAX_BYTES

      Nokogiri::XML(xml) { |config| config.strict.nonet.noblanks }.tap do |document|
        raise Error, "The SAML message has a document type, which isn't allowed." if document.internal_subset
      end
    rescue Nokogiri::XML::SyntaxError
      raise Error, "The SAML message isn't valid XML."
    end

    # @param xml [String] an unsigned document whose root has an ID attribute
    # @param certificate [SamlCertificate]
    # @return [String] the document with an enveloped signature
    def sign(xml, certificate)
      document = XMLSecurity::Document.new(xml)
      document.sign_document(certificate.signing_key, certificate.x509, SIGNATURE_METHOD, DIGEST_METHOD)
      document.to_s
    end

    # Signs a message for the HTTP-Redirect binding, as query parameters.
    # @param url [String] the destination
    # @param type [String] "SAMLRequest" or "SAMLResponse"
    # @param xml [String]
    # @param relay_state [String, nil]
    # @param certificate [SamlCertificate]
    # @return [String] the URL to send the browser to
    def redirect_url(url, type:, xml:, relay_state:, certificate:)
      query = OneLogin::RubySaml::Utils.build_query(type: type, data: Base64.strict_encode64(deflate(xml)), relay_state: relay_state, sig_alg: SIGNATURE_METHOD)
      signature = Base64.strict_encode64(certificate.signing_key.sign(OpenSSL::Digest.new("SHA256"), query))
      separator = url.include?("?") ? "&" : "?"
      "#{url}#{separator}#{query}&Signature=#{CGI.escape(signature)}"
    end

    # Checks the signature of a Redirect-binding message against the raw, still URL-encoded query.
    # @param raw_query [String] the request's query string
    # @param type [String] "SAMLRequest" or "SAMLResponse"
    # @param certificate [OpenSSL::X509::Certificate]
    # @return [Boolean]
    def redirect_signature_valid?(raw_query, type:, certificate:)
      raw = raw_query.to_s.split("&").to_h { |pair| pair.split("=", 2) }
      return false unless raw[type] && raw["SigAlg"] && raw["Signature"]

      signed = OneLogin::RubySaml::Utils.build_query_from_raw_parts(
        type: type, raw_data: raw[type], raw_relay_state: raw["RelayState"], raw_sig_alg: raw["SigAlg"]
      )
      OneLogin::RubySaml::Utils.verify_signature(
        cert: certificate, sig_alg: CGI.unescape(raw["SigAlg"]), signature: CGI.unescape(raw["Signature"]), query_string: signed
      )
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      false
    end

    # @param xml [String] a message with an enveloped signature
    # @param certificate [OpenSSL::X509::Certificate]
    # @return [Boolean]
    def embedded_signature_valid?(xml, certificate)
      document = XMLSecurity::SignedDocument.new(xml)
      return false unless REXML::XPath.first(document, "//ds:Signature", "ds" => XMLSecurity::Document::DSIG)

      document.validate_document_with_cert(certificate, true)
    rescue StandardError
      false
    end

    # @return [String] a SAML ID, which must not start with a digit
    def new_id
      "_#{SecureRandom.hex(20)}"
    end

    # @param time [Time]
    # @return [String]
    def timestamp(time)
      time.utc.iso8601
    end

    def inflate(data)
      Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data)
    end

    def deflate(xml)
      deflater = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS)
      deflater.deflate(xml, Zlib::FINISH).tap { deflater.close }
    end
  end
end
