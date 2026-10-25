# A signed-in user's own passkeys: list, add (options, then the new passkey), rename and remove.
# Includers define `relying_party`.
module OwnPasskeys
  extend ActiveSupport::Concern

  def index
    render json: PasskeySerializer.new(management.list).serializable_hash
  end

  def options
    render json: registration.options
  end

  def create
    passkey = registration.finish(**parse_request(::Passkeys::FinishRegistrationRequest).to_h)
    render json: PasskeySerializer.new(passkey).serializable_hash, status: :created
  end

  def update
    passkey = management.rename(management.find(params[:uid]), **parse_request(::Passkeys::RenameRequest).to_h)
    render json: PasskeySerializer.new(passkey).serializable_hash
  end

  def destroy
    management.remove(management.find(params[:uid]))
    head :no_content
  end

  private

  def registration
    ::Passkeys::Registration.new(user: current_user, relying_party: relying_party, authenticated_at: authenticated_at, **client_info)
  end

  def management
    ::Passkeys::Management.new(user: current_user, **client_info)
  end
end
