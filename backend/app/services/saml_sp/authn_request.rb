module SamlSp
  # A signed AuthnRequest to an upstream SAML provider, for the HTTP-Redirect binding.
  module AuthnRequest
    module_function

    # @param provider [IdentityProvider]
    # @param relay_state [String] brings the response back to its sign-in
    # @return [Array(String, String)] the URL to send the browser to, and the request's ID
    def url(provider, relay_state:)
      id = SamlIdp::Messages.new_id
      xml = %(<samlp:AuthnRequest xmlns:samlp="#{SamlIdp::Messages::PROTOCOL}" xmlns:saml="#{SamlIdp::Messages::ASSERTION}" ) +
        %(ID="#{id}" Version="2.0" IssueInstant="#{SamlIdp::Messages.timestamp(Time.current)}" Destination="#{escape(provider.saml_sso_url)}" ) +
        %(AssertionConsumerServiceURL="#{escape(provider.acs_url)}" ProtocolBinding="#{SamlIdp::Messages::POST_BINDING}">) +
        %(<saml:Issuer>#{escape(provider.sp_entity_id)}</saml:Issuer>) +
        %(<samlp:NameIDPolicy Format="#{SamlApp::NAME_ID_FORMATS.fetch(provider.saml_name_id_format)}" AllowCreate="true"/></samlp:AuthnRequest>)

      url = SamlIdp::Messages.redirect_url(
        provider.saml_sso_url, type: "SAMLRequest", xml: xml, relay_state: relay_state, certificate: SamlCertificate.active_for!(provider.project)
      )
      [ url, id ]
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
