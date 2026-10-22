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

SAML apps can't be tried this way: SAML posts the sign-in to a server that checks an XML signature.

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
