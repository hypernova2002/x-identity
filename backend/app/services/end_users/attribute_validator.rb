module EndUsers
  # Validates and normalises custom attribute values against a project's attribute definitions.
  # End users (signing up or editing their profile) may only set attributes marked user-editable;
  # admins may set any. Required attributes must end up with a value.
  class AttributeValidator
    Result = Data.define(:values, :details)

    # @param project [Project]
    def initialize(project:)
      @definitions = project.end_user_attribute_definitions.index_by(&:key)
    end

    # @param input [Hash] attribute values to set; `nil` clears a value
    # @param existing [Hash] the user's current values, for partial updates
    # @param by_admin [Boolean] whether non-user-editable attributes may be set
    # @return [Result] merged values, and field details for anything invalid
    def validate(input, existing: {}, by_admin: false)
      values = existing.to_h.stringify_keys
      details = []

      input.to_h.stringify_keys.each do |key, value|
        definition = @definitions[key]
        field = "custom_attributes.#{key}"

        if definition.nil?
          details << { field: field, message: "is not a known attribute" }
        elsif !by_admin && !definition.user_editable
          details << { field: field, message: "can't be changed" }
        elsif value.nil?
          values.delete(key)
        elsif (normalized = normalize(definition, value)).nil?
          details << { field: field, message: invalid_message(definition) }
        else
          values[key] = normalized
        end
      end

      reported = details.map { |detail| detail[:field] }
      @definitions.each_value do |definition|
        next unless definition.required && (by_admin || definition.user_editable)
        next if values.key?(definition.key) || reported.include?("custom_attributes.#{definition.key}")

        details << { field: "custom_attributes.#{definition.key}", message: "is required" }
      end

      Result.new(values: values, details: details)
    end

    private

    def normalize(definition, value)
      case definition.data_type
      when "string"
        max = definition.max_length || EndUserAttributeDefinition::MAX_STRING_LENGTH
        value if value.is_a?(String) && value.length <= max
      when "number"
        value if value.is_a?(Numeric) && value.to_f.finite?
      when "boolean"
        value if [ true, false ].include?(value)
      when "date"
        Date.iso8601(value).iso8601 if value.is_a?(String)
      end
    rescue Date::Error
      nil
    end

    def invalid_message(definition)
      case definition.data_type
      when "string" then "must be text of at most #{definition.max_length || EndUserAttributeDefinition::MAX_STRING_LENGTH} characters"
      when "number" then "must be a number"
      when "boolean" then "must be true or false"
      when "date" then "must be a date like 2026-01-31"
      end
    end
  end
end
