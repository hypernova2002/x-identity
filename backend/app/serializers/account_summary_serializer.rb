# The public view of an account, returned before anyone signs in.
class AccountSummarySerializer
  include Alba::Resource

  attributes :uid, :name, :slug
end
