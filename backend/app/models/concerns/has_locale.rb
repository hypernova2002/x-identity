# The language a user chose for the console and hosted pages. Null means they haven't chosen, and
# the pages follow the browser's language.
module HasLocale
  extend ActiveSupport::Concern

  LOCALES = %w[en ja].freeze

  included do
    validates :locale, inclusion: { in: LOCALES }, allow_nil: true
  end
end
