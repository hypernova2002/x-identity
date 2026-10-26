# Example apps

The `examples` Compose service serves a tiny OpenID Connect app for trying hosted login, single
sign-on and the app portal by hand. It's plain HTML and JavaScript (`examples/oidc-app/`), with no
build step and no dependencies, served by nginx as two apps on two origins:

| App | URL |
| --- | --- |
| Shop | http://localhost:5190 |
| Wiki | http://localhost:5191 |

Each app is a public client using the authorization code flow with PKCE
(`openid email profile groups offline_access`). It shows the ID token claims and the userinfo
response, and can refresh its tokens, sign in again (`prompt=login`) and log out.

For SAML apps there's a test service provider, below.

## Setting up

For each app, in a project:

1. Create a **public** app client (e.g. "Shop (example)") with:
   - allowed origin: `http://localhost:5190`
   - redirect URI and post-logout redirect URI: `http://localhost:5190/`
   - launch URL: `http://localhost:5190/?login=1`
2. Give end users access with **Access** (e.g. the **All end users** group).
3. Open the app and enter the project's issuer (from the project overview) and the client ID. They're
   saved in the browser; **Settings** changes them.

Use port `5191` for Wiki.

## A SAML app

The `saml-sp` Compose service (`examples/saml-sp/config.ru`) is a tiny SAML service provider at
http://localhost:5192. It runs on the backend image with ruby-saml, and shows what the identity
provider sent: whether the response is valid (signed by the project, for this app, in date), the
NameID, the attributes and the response XML. It reads the project's SAML metadata on every request.

1. Set `IDP_METADATA_URL` on the `saml-sp` service in your `docker-compose.yml` to the project's
   metadata as the container reaches the backend:
   `http://backend:3000/v1/accounts/<account_uid>/projects/<project_uid>/saml/metadata`, then
   `docker compose up -d saml-sp`.
2. In the project, add a SAML application with:
   - entity ID: `http://localhost:5192/metadata` (or import that metadata URL)
   - ACS URL: `http://localhost:5192/acs`
   - NameID format: email, and any attribute mappings, e.g. `email`, `name`, `groups`
   - **Domain**: the standard URLs, since the service provider reads the standard metadata
3. Give end users access (e.g. the **All end users** group).
4. Open http://localhost:5192 and **Sign in with x-identity** (SP-initiated), or launch the app
   from the app portal (IdP-initiated).

## The app portal

Every project has a built-in **app portal** at
`{console}/auth/:alias/:project_uid/apps` (e.g. `http://localhost:5173/auth/acme/proj_…/apps`),
also linked from the project overview and from the example apps' pages. Signed-in users see the
apps they're assigned: app clients with a launch URL, like Shop and Wiki, and SAML apps.

1. Open the portal. With no hosted login session, it sends you to the login page first.
2. Shop and Wiki are listed. Click one: its launch URL (`/?login=1`) starts a sign-in, and the
   single sign-on session brings it straight back signed in.
3. **Log out** in the portal ends the session; the apps need the login page again next time.

An app only appears when it's assigned to the user and has a launch URL. See
[SAML apps and the app portal](saml-apps-and-portal.md#the-app-portal) for how it works.

## Things to try

- **Hosted login**: sign in to Shop. The hosted page handles the password, any MFA challenge, social
  and SAML providers, sign-up and password reset.
- **Single sign-on**: then sign in to Wiki. It comes straight back signed in, without the login page.
- **Assignment**: remove a user's access to Wiki, then sign in to it: the app gets `access_denied`.
  Refreshing Wiki's tokens fails with `invalid_grant` too.
- **Re-authentication**: **Sign in again** sends `prompt=login`, which shows the login page even
  with a session.
- **Logout**: **Log out** ends the hosted login session (and logs out of SAML apps). The other app
  keeps its tokens until they expire, but its next sign-in needs the login page again.
- **Refresh**: **Refresh tokens** rotates the refresh token; the claims show the new `iat`.
