module ModelErrorHelpers
  # @return [Array<Symbol>] the error codes validation adds to the attribute
  def error_codes(record, attribute)
    record.validate
    record.errors.details[attribute].map { |detail| detail[:error] }
  end
end

RSpec.configure { |config| config.include ModelErrorHelpers }
