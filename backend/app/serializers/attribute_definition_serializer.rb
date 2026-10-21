class AttributeDefinitionSerializer
  include Alba::Resource

  attributes :uid, :key, :label, :data_type, :required, :max_length, :user_editable, :include_in_token, :created_at, :updated_at
end
