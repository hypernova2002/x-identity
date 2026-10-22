class AppAssignmentSerializer
  include Alba::Resource

  attributes :uid, :created_at
  attribute(:principal_type) { |assignment| assignment.principal_type.underscore }
  attribute(:principal_uid) { |assignment| assignment.principal.uid }
  attribute(:principal_label) { |assignment| assignment.principal.is_a?(Group) ? assignment.principal.name : assignment.principal.email }
end
