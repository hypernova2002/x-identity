module IdentityProviders
  # Console-side setup of a project's identity providers. Secrets are write-only: they're never
  # returned, and an update without one keeps the current secret.
  class Management
    EDITABLE = %i[name enabled client_id client_secret additional_audiences scopes discovery_url apple_team_id apple_key_id apple_private_key].freeze
    SECRET_FIELDS = %w[client_secret apple_private_key].freeze

    # @param actor [User]
    # @param project [Project]
    # @param ip [String, nil] the caller's IP address, for the audit log
    # @param user_agent [String, nil]
    # @param discovery [Discovery]
    def initialize(actor:, project:, ip: nil, user_agent: nil, discovery: Discovery.new)
      @actor = actor
      @project = project
      @ip = ip
      @user_agent = user_agent
      @discovery = discovery
    end

    # @param kind [String] "google", "apple" or "oidc"
    # @param attributes [Hash] any of {EDITABLE}
    # @return [IdentityProvider]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def create(kind:, **attributes)
      authorize!
      provider = @project.identity_providers.new(kind: kind, **attributes.slice(*EDITABLE))
      load_metadata(provider)
      raise ApiError.from_record(provider) unless provider.save

      recorder.record(action: "identity_provider.created", actor: @actor, target: provider, metadata: { kind: kind })
      provider
    end

    # @param provider [IdentityProvider]
    # @param changes [Hash] any of {EDITABLE}; blank secrets are ignored
    # @return [IdentityProvider]
    # @raise [ApiError] `forbidden` or `validation_failed`
    def update(provider, **changes)
      authorize!
      changes = changes.slice(*EDITABLE).reject { |field, value| SECRET_FIELDS.include?(field.to_s) && value.blank? }
      provider.assign_attributes(changes)
      load_metadata(provider) if provider.discovery_url_changed?
      changed = provider.changes.except("metadata").to_h do |field, (from, to)|
        [ field, SECRET_FIELDS.include?(field) ? "changed" : { from: from, to: to } ]
      end
      raise ApiError.from_record(provider) unless provider.save

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
        provider.identities.delete_all.tap { provider.destroy! }
      end
      recorder.record(action: "identity_provider.deleted", actor: @actor, target: provider, metadata: { unlinked_identities: unlinked })
    end

    private

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
