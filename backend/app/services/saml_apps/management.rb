module SamlApps
  class Management
    EDITABLE = %i[
      name enabled entity_id acs_urls slo_url sp_certificate name_id_format attribute_mappings
      sign_assertion sign_response require_signed_requests default_relay_state
    ].freeze

    # @param actor [User]
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param http_client [IdentityProviders::HttpClient] fetches metadata from URLs
    def initialize(actor:, project:, ip: nil, user_agent: nil, http_client: IdentityProviders::HttpClient.new)
      @actor = actor
      @project = project
      @ip = ip
      @user_agent = user_agent
      @http_client = http_client
    end

    # New apps need an assignment before anyone can use them.
    # @param attributes [Hash] any of {EDITABLE}
    # @return [SamlApp]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(**attributes)
      authorize!
      app = @project.saml_apps.new(normalize(attributes))
      raise ApiError.from_record(app) unless app.save

      recorder.record(action: "saml_app.created", actor: @actor, target: app)
      app
    end

    # @param app [SamlApp]
    # @param changes [Hash] any of {EDITABLE}
    # @return [SamlApp]
    def update(app, **changes)
      authorize!
      app.assign_attributes(normalize(changes))
      changed = app.changes.transform_values { |from, to| { from: from, to: to } }
      raise ApiError.from_record(app) unless app.save

      recorder.record(action: "saml_app.updated", actor: @actor, target: app, metadata: { changes: changed.except("sp_certificate").merge(changed.key?("sp_certificate") ? { "sp_certificate" => "changed" } : {}) }) if changed.any?
      app
    end

    # @param app [SamlApp]
    def destroy(app)
      authorize!
      SamlApp.transaction do
        OneTimeToken.where(subject: app).delete_all
        app.destroy!
      end
      recorder.record(action: "saml_app.deleted", actor: @actor, target: app)
    end

    # Reads an app's SAML metadata, for filling in the form; nothing is saved.
    # @param metadata_xml [String, nil]
    # @param metadata_url [String, nil]
    # @return [Hash]
    # @raise [ApiError] `validation_failed`
    def parse_metadata(metadata_xml: nil, metadata_url: nil)
      authorize!
      raise ApiError.validation(metadata: "send either metadata_xml or metadata_url") unless metadata_xml.present? ^ metadata_url.present?

      xml = metadata_xml.presence || @http_client.get_text(metadata_url)
      SamlIdp::SpMetadata.parse(xml)
    rescue IdentityProviders::HttpClient::Error => error
      raise ApiError.validation(metadata_url: "couldn't be loaded: #{error.message}")
    end

    private

    def normalize(attributes)
      attributes.slice(*EDITABLE).to_h do |field, value|
        value = value.map { |mapping| mapping.to_h.stringify_keys } if field == :attribute_mappings
        value = value.presence if %i[slo_url sp_certificate default_relay_state].include?(field)
        [ field, value ]
      end
    end

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_app_clients?
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
