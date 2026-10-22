# A SAML app a browser session signed in to, with the NameID and SessionIndex it was given, so
# single logout can log the user out of it.
class BrowserSessionApp < ApplicationRecord
  belongs_to :browser_session
  belongs_to :saml_app
end
