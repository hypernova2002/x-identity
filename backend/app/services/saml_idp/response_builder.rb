module SamlIdp
  # Builds a SAML Response for an app: a successful one with an assertion about the user, or an
  # error status. Assertions are valid for five minutes and only for the app's entity ID.
  class ResponseBuilder
    VALIDITY = 5.minutes
    SUCCESS = "urn:oasis:names:tc:SAML:2.0:status:Success".freeze
    PASSWORD_CONTEXT = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport".freeze
    MFA_CONTEXT = "https://refeds.org/profile/mfa".freeze
    UNSPECIFIED_CONTEXT = "urn:oasis:names:tc:SAML:2.0:ac:classes:unspecified".freeze
    ATTRIBUTE_NAME_FORMAT = "urn:oasis:names:tc:SAML:2.0:attrname-format:basic".freeze

    # @param app [SamlApp]
    def initialize(app)
      @app = app
      @project = app.project
      @issuer = Metadata.new(@project, endpoints: app.project_endpoints).entity_id
    end

    # @param end_user [EndUser]
    # @param acs_url [String]
    # @param in_response_to [String, nil] the request's ID; nil for IdP-initiated sign-in
    # @param session_index [String]
    # @param authenticated_at [Time]
    # @param amr [Array<String>]
    # @return [String] base64 XML
    def success(end_user:, acs_url:, in_response_to:, session_index:, authenticated_at:, amr:)
      now = Time.current
      assertion = assertion_xml(end_user, acs_url, in_response_to, session_index, authenticated_at, amr, now)
      assertion = Messages.sign(assertion, certificate) if @app.sign_assertion
      encode(response_xml(acs_url, in_response_to, now, SUCCESS, nil, assertion), sign: @app.sign_response)
    end

    # @param acs_url [String]
    # @param in_response_to [String, nil]
    # @param status [String] a top-level status, e.g. Responder
    # @param sub_status [String, nil] e.g. NoPassive or RequestDenied
    # @return [String] base64 XML
    def failure(acs_url:, in_response_to:, status:, sub_status: nil)
      encode(response_xml(acs_url, in_response_to, Time.current, "urn:oasis:names:tc:SAML:2.0:status:#{status}", sub_status, nil), sign: true)
    end

    # @param end_user [EndUser]
    # @return [String] the NameID the app knows the user by
    def name_id_for(end_user)
      @app.name_id_format == "persistent" ? end_user.uid : end_user.email
    end

    private

    def certificate
      @certificate ||= SamlCertificate.active_for!(@project)
    end

    def encode(xml, sign:)
      Base64.strict_encode64(sign ? Messages.sign(xml, certificate) : xml)
    end

    def response_xml(acs_url, in_response_to, now, status, sub_status, assertion)
      attributes = { "ID" => Messages.new_id, "Version" => "2.0", "IssueInstant" => Messages.timestamp(now), "Destination" => acs_url }
      attributes["InResponseTo"] = in_response_to if in_response_to
      status_xml = %(<samlp:StatusCode Value="#{status}">#{%(<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:#{sub_status}"/>) if sub_status}</samlp:StatusCode>)

      %(<samlp:Response xmlns:samlp="#{Messages::PROTOCOL}" xmlns:saml="#{Messages::ASSERTION}" #{xml_attributes(attributes)}>) +
        %(<saml:Issuer>#{escape(@issuer)}</saml:Issuer><samlp:Status>#{status_xml}</samlp:Status>#{assertion}</samlp:Response>)
    end

    def assertion_xml(end_user, acs_url, in_response_to, session_index, authenticated_at, amr, now)
      confirmation = { "NotOnOrAfter" => Messages.timestamp(now + VALIDITY), "Recipient" => acs_url }
      confirmation["InResponseTo"] = in_response_to if in_response_to

      Nokogiri::XML::Builder.new do |xml|
        # The signature's inclusive namespaces include samlp, which the Response declares, so the
        # assertion declares it too: otherwise it canonicalises differently once embedded.
        xml["saml"].Assertion(
          "xmlns:saml" => Messages::ASSERTION, "xmlns:samlp" => Messages::PROTOCOL, "xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
          "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
          "ID" => Messages.new_id, "Version" => "2.0", "IssueInstant" => Messages.timestamp(now)
        ) do
          xml["saml"].Issuer(@issuer)
          xml["saml"].Subject do
            xml["saml"].NameID(name_id_for(end_user), "Format" => @app.name_id_format_uri)
            xml["saml"].SubjectConfirmation("Method" => "urn:oasis:names:tc:SAML:2.0:cm:bearer") do
              xml["saml"].SubjectConfirmationData(confirmation)
            end
          end
          xml["saml"].Conditions("NotBefore" => Messages.timestamp(now - 1.minute), "NotOnOrAfter" => Messages.timestamp(now + VALIDITY)) do
            xml["saml"].AudienceRestriction { xml["saml"].Audience(@app.entity_id) }
          end
          xml["saml"].AuthnStatement("AuthnInstant" => Messages.timestamp(authenticated_at), "SessionIndex" => session_index) do
            xml["saml"].AuthnContext { xml["saml"].AuthnContextClassRef(authn_context(amr)) }
          end
          attribute_statement(xml, end_user)
        end
      end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION).strip
    end

    def attribute_statement(xml, end_user)
      values = @app.attribute_mappings.map { |mapping| [ mapping["name"], attribute_values(end_user, mapping["source"]) ] }
      return if values.empty?

      xml["saml"].AttributeStatement do
        values.each do |name, list|
          xml["saml"].Attribute("Name" => name, "NameFormat" => ATTRIBUTE_NAME_FORMAT) do
            list.each { |value| xml["saml"].AttributeValue(value, "xsi:type" => "xs:string") }
          end
        end
      end
    end

    def attribute_values(end_user, source)
      case source
      when "email" then [ end_user.email ]
      when "email_verified" then [ end_user.email_verified?.to_s ]
      when "name" then [ end_user.name.to_s ]
      when "uid" then [ end_user.uid ]
      when "groups" then end_user.groups.order(:name).pluck(:name)
      else Array(end_user.custom_attributes[source.delete_prefix("custom:")]).map(&:to_s)
      end
    end

    def authn_context(amr)
      return MFA_CONTEXT if amr.include?("otp")
      return PASSWORD_CONTEXT if amr.include?("pwd")

      UNSPECIFIED_CONTEXT
    end

    def xml_attributes(attributes)
      attributes.map { |name, value| %(#{name}="#{escape(value)}") }.join(" ")
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
