module SamlSp
  # Verifies a SAML Response from an upstream provider (with ruby-saml's service provider checks:
  # signature, issuer, audience, destination, recipient, time window and InResponseTo), makes sure
  # each assertion is only used once, and reads the user's details from it.
  class ResponseValidator
    CLOCK_DRIFT = 60.seconds
    TRANSIENT = "urn:oasis:names:tc:SAML:2.0:nameid-format:transient".freeze

    # @param provider [IdentityProvider]
    def initialize(provider)
      @provider = provider
    end

    # @param saml_response [String] base64, as posted to the ACS URL
    # @param request_id [String, nil] the AuthnRequest's ID; nil for IdP-initiated sign-in
    # @return [Hash{String => Object}] claims for {IdentityProviders::UserResolver}, plus name_id,
    #   name_id_format and session_index for single logout
    # @raise [ApiError] `invalid_saml_response`
    def validate(saml_response, request_id:)
      response = OneLogin::RubySaml::Response.new(saml_response.to_s, settings: settings, matches_request_id: request_id, allowed_clock_drift: CLOCK_DRIFT)
      reject!(:saml_response_not_valid, response.errors.join("; ")) unless response.is_valid?
      reject!(:saml_response_unrequested) if request_id.nil? && response.in_response_to.present?
      reject!(:saml_response_transient_name_id) if response.name_id_format == TRANSIENT
      reject!(:saml_response_reused) unless ConsumedSamlAssertion.consume(@provider, response.assertion_id.to_s, response.not_on_or_after || 5.minutes.from_now)

      claims_from(response)
    rescue OneLogin::RubySaml::ValidationError, REXML::ParseException, ArgumentError => error
      reject!(:saml_response_unreadable, error.message)
    end

    private

    def settings
      OneLogin::RubySaml::Settings.new.tap do |settings|
        settings.sp_entity_id = @provider.sp_entity_id
        settings.assertion_consumer_service_url = @provider.acs_url
        settings.idp_entity_id = @provider.saml_idp_entity_id
        settings.idp_cert_multi = { signing: Array(@provider.saml_idp_certificates), encryption: [] }
      end
    end

    def claims_from(response)
      email = attribute(response, @provider.saml_email_attribute) || (response.nameid if response.nameid.to_s.match?(URI::MailTo::EMAIL_REGEXP))
      claims = {
        "sub" => response.nameid.to_s,
        "email" => email,
        "email_verified" => @provider.authoritative_for?(email),
        "name" => attribute(response, @provider.saml_name_attribute),
        "name_id" => response.nameid.to_s,
        "name_id_format" => response.name_id_format,
        "session_index" => response.sessionindex
      }
      claims["groups"] = Array(response.attributes.multi(@provider.saml_groups_attribute)).map(&:to_s) if @provider.saml_groups_attribute.present?
      claims
    end

    def attribute(response, name)
      return nil if name.blank?

      response.attributes.single(name).presence&.to_s
    end

    def reject!(reason, problem = nil)
      Rails.logger.info("SAML response from identity provider #{@provider.uid}: #{reason}#{" (#{problem})" if problem}")
      raise ApiError.new(:invalid_saml_response, reason: reason, params: { provider: @provider.name })
    end
  end
end
