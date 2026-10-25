# The public view of an account, returned before anyone signs in.
class AccountSummarySerializer
  include Alba::Resource

  attributes :uid, :name, :slug
  # Whether the sign-in page offers passkeys.
  attribute(:passkeys) { |account| account.auth_configuration!.passkeys_optional? }
end
