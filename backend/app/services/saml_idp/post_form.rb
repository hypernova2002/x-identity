module SamlIdp
  # The HTTP-POST binding: a page that posts SAML fields to the app as soon as it loads.
  module PostForm
    module_function

    # @param url [String] the app's endpoint, already checked against its registered URLs
    # @param fields [Hash{String => String, nil}]
    # @return [String] HTML
    def html(url, fields)
      inputs = fields.compact.map { |name, value| %(<input type="hidden" name="#{escape(name)}" value="#{escape(value)}">) }.join
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head><meta charset="utf-8"><meta name="referrer" content="no-referrer"><title>Signing in…</title></head>
          <body onload="document.forms[0].submit()">
            <form method="post" action="#{escape(url)}">#{inputs}<noscript><button type="submit">Continue</button></noscript></form>
          </body>
        </html>
      HTML
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
