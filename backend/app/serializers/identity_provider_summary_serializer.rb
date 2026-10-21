# What apps need to show sign-in buttons.
class IdentityProviderSummarySerializer
  include Alba::Resource

  attributes :uid, :kind, :name
end
