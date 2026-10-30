module AppClients
  # Field types shared by the app client requests.
  module Fields
    T = RequestTypes::T

    Name = RequestTypes::Name.meta(description: "The app's name.")
    AllowedOrigins = T::Array.of(T::String.constrained(min_size: 1, max_size: 255)).constrained(max_size: AppClient::MAX_ORIGINS)
      .meta(description: "Browser origins allowed to call the API, e.g. https://shop.example.com.")
    RedirectUris = T::Array.of(RequestTypes::Url).constrained(max_size: AppClient::MAX_REDIRECT_URIS)
      .meta(description: "Where users may be sent back after signing in with an identity provider, compared exactly: " \
        "https URLs, http://localhost URLs, or app schemes like com.example.app:/callback.")
    PostLogoutRedirectUris = RedirectUris.meta(description: "Where apps may send users after logging out of hosted login, compared exactly.")
    LaunchUrl = RequestTypes::Url.optional.meta(description: "Where the app portal opens the app. Apps without one aren't listed in the portal.")
  end
end
