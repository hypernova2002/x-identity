class InvitationSerializer
  include Alba::Resource

  attributes :uid, :email, :role, :expires_at, :created_at

  attribute(:invited_by_uid) { |invitation| invitation.invited_by&.uid }
end
