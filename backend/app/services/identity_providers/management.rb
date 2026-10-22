module IdentityProviders
  # Console-side setup of a project's identity providers. Secrets are write-only: they're never
  # returned, and an update without one keeps the current secret.
  class Management
    EDITABLE = %i[
      name enabled client_id client_secret additional_audiences scopes discovery_url apple_team_id apple_key_id apple_private_key
      saml_idp_entity_id saml_sso_url saml_slo_url saml_idp_certificates saml_name_id_format saml_email_attribute saml_name_attribute
      saml_groups_attribute domains create_users allow_idp_initiated
    ].freeze
    BLANK_TO_NIL = %i[saml_slo_url saml_email_attribute saml_name_attribute saml_groups_attribute].freeze
    SECRET_FIELDS = %w[client_secret apple_private_key].freeze

    # @param actor [User]
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param discovery [Discovery]
    # @param http_client [HttpClient] fetches SAML metadata from URLs
    def initialize(actor:, project:, ip: nil, user_agent: nil, discovery: Discovery.new, http_client: HttpClient.new)
      @actor = actor
      @project = project
      @ip = ip
      @user_agent = user_agent
      @discovery = discovery
      @http_client = http_client
    end

    # @param kind [String] "google", "apple", "oidc" or "saml"
    # @param attributes [Hash] any of {EDITABLE}, and group_mappings
    # @return [IdentityProvider]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(kind:, group_mappings: nil, **attributes)
      authorize!
      provider = @project.identity_providers.new(kind: kind, **normalize(attributes))
      load_metadata(provider)
      mappings = mappings_for(group_mappings) if group_mappings
      IdentityProvider.transaction do
        raise ApiError.from_record(provider) unless provider.save

        replace_mappings(provider, mappings) if mappings
      end

      recorder.record(action: "identity_provider.created", actor: @actor, target: provider, metadata: { kind: kind })
      provider
    end

    # @param provider [IdentityProvider]
    # @param changes [Hash] any of {EDITABLE}, and group_mappings; blank secrets are ignored
    # @return [IdentityProvider]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def update(provider, group_mappings: nil, **changes)
      authorize!
      changes = normalize(changes).reject { |field, value| SECRET_FIELDS.include?(field.to_s) && value.blank? }
      provider.assign_attributes(changes)
      load_metadata(provider) if provider.discovery_url_changed?
      mappings = mappings_for(group_mappings) if group_mappings
      changed = provider.changes.except("metadata").to_h do |field, (from, to)|
        [ field, SECRET_FIELDS.include?(field) ? "changed" : { from: from, to: to } ]
      end
      changed["group_mappings"] = "changed" if mappings
      IdentityProvider.transaction do
        raise ApiError.from_record(provider) unless provider.save

        replace_mappings(provider, mappings) if mappings
      end

      recorder.record(action: "identity_provider.updated", actor: @actor, target: provider, metadata: { changes: changed }) if changed.any?
      provider
    end

    # Deletes the provider and unlinks every end user from it. Users with no password and no other
    # identity can no longer sign in until they reset their password.
    # @param provider [IdentityProvider]
    def destroy(provider)
      authorize!
      unlinked = IdentityProvider.transaction do
        OneTimeToken.where(subject: provider).delete_all
        BrowserSession.where(identity_provider: provider).update_all(identity_provider_id: nil)
        provider.identities.delete_all.tap { provider.destroy! }
      end
      recorder.record(action: "identity_provider.deleted", actor: @actor, target: provider, metadata: { unlinked_identities: unlinked })
    end

    # Reads an upstream SAML provider's metadata, for filling in the form; nothing is saved.
    # @param metadata_xml [String, nil]
    # @param metadata_url [String, nil]
    # @return [Hash]
    # @raise [ApiError] `validation_failed`
    def parse_saml_metadata(metadata_xml: nil, metadata_url: nil)
      authorize!
      raise ApiError.validation(metadata: "send either metadata_xml or metadata_url") unless metadata_xml.present? ^ metadata_url.present?

      SamlSp::IdpMetadata.parse(metadata_xml.presence || @http_client.get_text(metadata_url))
    rescue HttpClient::Error => error
      raise ApiError.validation(metadata_url: "couldn't be loaded: #{error.message}")
    end

    private

    def normalize(attributes)
      attributes.slice(*EDITABLE).to_h { |field, value| [ field, BLANK_TO_NIL.include?(field) ? value.presence : value ] }
    end

    # @return [Array<Hash>] value and group pairs, checked to be in the project
    # @raise [ApiError] `validation_failed` for unknown groups
    def mappings_for(group_mappings)
      groups = @project.groups.where(uid: group_mappings.map { |mapping| mapping[:group_uid] }).index_by(&:uid)
      unknown = group_mappings.map { |mapping| mapping[:group_uid] }.uniq - groups.keys
      raise ApiError.validation(group_mappings: "refers to unknown groups: #{unknown.join(', ')}") if unknown.any?

      group_mappings.map { |mapping| { value: mapping[:value], group: groups.fetch(mapping[:group_uid]) } }.uniq
    end

    def replace_mappings(provider, mappings)
      provider.group_mappings.delete_all
      mappings.each { |mapping| provider.group_mappings.create!(value: mapping[:value], group: mapping[:group]) }
    end

    def load_metadata(provider)
      return unless provider.kind_oidc? && provider.discovery_url.present?

      provider.metadata = @discovery.fetch(provider.discovery_url)
    end

    def authorize!
      raise ApiError.new(:forbidden) unless ProjectPolicy.new(@actor, @project).manage_settings?
    end

    def recorder
      @project.realm.recorder(ip: @ip, user_agent: @user_agent)
    end
  end
end
