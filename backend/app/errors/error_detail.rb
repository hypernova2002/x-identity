# A field-level problem in an error response: the field, a code clients translate (with the values
# its message refers to, such as a length limit), and an English message. Messages are in
# config/locales/en.yml under `errors.messages`, alongside Rails' own.
module ErrorDetail
  # @param field [String, Symbol]
  # @param code [Symbol] a key of `errors.messages`
  # @param params [Hash] values the message refers to, e.g. `count`
  # @return [Hash{Symbol => Object}]
  def self.build(field, code, **params)
    { field: field.to_s, code: code.to_s, message: message(code, params), params: params }
  end

  # @param error [ActiveModel::Error] an error added with a symbol, e.g. `errors.add(:name, :taken)`.
  #   A validation's `message: :code` names the code, rather than the validation's type.
  # @param field [String, Symbol] the request field the attribute is sent as
  # @return [Hash{Symbol => Object}]
  def self.from(error, field: error.attribute)
    code = error.options[:message].is_a?(Symbol) ? error.options[:message] : error.type
    build(field, code, **error.details.except(:error, :value))
  end

  # @param code [Symbol]
  # @param params [Hash]
  # @return [String]
  def self.message(code, params)
    I18n.t(code, scope: "errors.messages", **interpolations(params), locale: :en, raise: true)
  end

  # Lists read as "a, b" in messages, and stay arrays in `params`.
  def self.interpolations(params)
    params.transform_values { |value| value.is_a?(Array) ? value.join(", ") : value }
  end
  private_class_method :interpolations
end
