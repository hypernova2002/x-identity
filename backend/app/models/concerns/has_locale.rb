# The language a user chose for the console, hosted pages and emails. Null means they haven't
# chosen: the pages follow the browser's language, and emails the language of the request that sent
# them.
module HasLocale
  extend ActiveSupport::Concern

  LOCALES = I18n.available_locales.map(&:to_s).freeze

  included do
    validates :locale, inclusion: { in: LOCALES }, allow_nil: true
  end
end
