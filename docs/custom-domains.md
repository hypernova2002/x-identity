# Custom domains

A project can have its own domain, such as `login.acme.com`, for its hosted login and endpoints.
Admins add it on the project's **Custom domain** page. Nothing changes for existing apps when a
domain is added or verified: the project's standard URLs keep working, and apps move to the domain
when they're configured with it.

## Verifying a domain

Use a subdomain you control. The console shows two DNS records to create at its DNS provider:

| Type | Name | Value |
| --- | --- | --- |
| CNAME | `login.acme.com` | the platform's target (`CUSTOM_DOMAIN_TARGET`) |
| TXT | `_x-identity.login.acme.com` | the domain's verification token |

The TXT record proves the project's owner controls the domain; the CNAME points it at x-identity.
A background job checks both, starting a minute after the domain is added and backing off to
hourly, for up to 72 hours; **Check now** checks straight away. Each check shows what's wrong, for
example a CNAME pointing elsewhere. A domain still unverified after 72 hours is marked failed;
fix the records and check again, or remove it.

A domain can only be used by one project. x-identity's own hosts and their subdomains can't be
used.

## Keeping and replacing a domain

Keep both records while the domain is in use. Verified domains are re-checked hourly; if their
records disappear the domain stays in use, but the console flags it and shows since when.

A project has one domain in use and can set up one replacement at a time. The replacement is
checked while the current domain keeps working, and takes over once it's verified.

Audit events: `domain.added`, `domain.verified`, `domain.failed` and `domain.removed` (with
`replaced_by` when a replacement took over).

## What a verified domain serves

The project's public endpoints, at the root of the domain:

| Path | |
| --- | --- |
| `/.well-known/openid-configuration`, `/.well-known/jwks.json` | Discovery and keys; the domain is the issuer |
| `/.well-known/webauthn` | The apps' allowed origins that can use the domain's [passkeys](passkeys.md) |
| `/oauth2/*` | Authorize, token, userinfo, revoke, logout, hosted login interactions |
| `/saml/*` | SAML sign-on, logout, metadata and app launches |
| `/auth/*` | The end-user sign-in API, plus `/auth/domain`, which tells hosted pages their project |
| `/portal`, `/me` | The app portal's settings and apps, and the signed-in end user's own endpoints |
| `/login`, `/apps`, `/error`, `/signed-out` | Hosted login and the app portal (the web app) |

x-identity's own API (`/v1/...`) isn't served on custom domains.

**Issuer.** Tokens carry the issuer of the domain their sign-in started on:
`https://login.acme.com` on the custom domain, the standard issuer otherwise. A sign-in remembers
where it started, so the hosted page, the code and the tokens all stay on one domain; refreshed
tokens keep their issuer wherever they're refreshed. Tokens with either issuer are accepted by
userinfo, revocation and logout on either URL, and are signed with the same keys.

**Sessions.** The single sign-on cookie is first-party on the custom domain, for the whole domain.
Sessions on the custom domain and on the standard URLs are separate, so apps sign users in once per
domain.

**Emails.** Links to the app portal in emails use the custom domain once it's verified.

**Sign-ins through identity providers.** Social and OpenID Connect providers keep returning to
the callback URL registered with them, on the standard URLs, and SAML providers to their ACS URL.
When a sign-in that started on the custom domain comes back there, it's handed back to the custom
domain with a single-use, short-lived ticket, and the session is created on the custom domain. The
callback URLs registered with providers never need to change.

## SAML apps and SAML identity providers

The other side of a SAML connection has x-identity's entity ID and URLs saved, and checks them, so
they don't follow the domain automatically. Each SAML app and SAML identity provider records whether
it uses the custom domain:

| | Standard URLs | Custom domain |
| --- | --- | --- |
| SAML app: entity ID and metadata | `…/projects/<uid>/saml/metadata` | `https://login.acme.com/saml/metadata` |
| SAML app: sign-on and logout | `…/saml/sso`, `…/saml/slo` | `https://login.acme.com/saml/sso`, `/saml/slo` |
| SAML identity provider: SP entity ID, ACS, logout | `…/saml/sp/<uid>/metadata`, `/acs`, `/slo` | `https://login.acme.com/saml/sp/<uid>/…` |

- Existing apps and providers stay on the standard URLs. Ones created after the domain is verified
  start on it.
- The **Domain** card on a SAML app's Credentials tab, or a SAML provider's page, switches it. The
  confirmation says what to update on the other side: re-import the metadata in the app, or send the
  new metadata URL to the identity provider's admin. Sign-ins fail until that's done.
- An app's assertions are issued with its own entity ID, whichever domain the request arrives on,
  and both domains answer its SAML endpoints, so an app that only updated its sign-on URL keeps
  working. Responses from a provider are checked against the URLs it was set up with.
- The signing certificates are the project's, on both domains.
- Removing the domain moves apps and providers that use it back to the standard URLs; replacing it
  moves them to the new domain. The Domain page lists which ones are affected before either.
- The project overview lists apps and providers still on the standard URLs once a domain is in use.

## Routing in production

The proxy in front of x-identity terminates TLS for custom domains and routes by path on them:

| Path on a custom domain | Goes to |
| --- | --- |
| `/.well-known/*`, `/oauth2/*`, `/saml/*`, `/auth/*`, `/portal`, `/portal/*`, `/me`, `/me/*` | The backend, with the original `Host` header |
| Everything else | The web app (its built files, with `index.html` for unknown paths) |

The backend recognises the project from the `Host` header. If Rails host authorization
(`config.hosts`) is turned on in production, it must allow the verified domains too.

## Certificates

HTTPS certificates for custom domains are issued outside x-identity, by the proxy in front of it.
Before issuing one, the proxy can ask whether a hostname is a verified domain of an active project:

```
GET /internal/domains/allowed?domain=login.acme.com   → 200 if verified, 404 otherwise
```

This is the shape Caddy's on-demand TLS `ask` option expects. The endpoint is rate limited and
reveals nothing beyond whether the domain is verified.

## Configuration

| Variable | Default | |
| --- | --- | --- |
| `CUSTOM_DOMAIN_TARGET` | `domains.x-identity.localhost` | The hostname customers' CNAME records point at |

| `CUSTOM_DOMAIN_LOCAL_PORT` | none | Development only: the edge service's port, part of `*.localhost` domains' URLs |
| `VITE_CONSOLE_URL` (web) | none | Where the console is served; on any other origin the web app runs only hosted pages |

In development, `*.localhost` domains (e.g. `login.acme.localhost`) verify without DNS, since
browsers resolve them to your machine. They're refused in production. The `edge` service (Caddy,
plain HTTP) routes them like the production proxy: add a domain such as `login.acme.localhost` to a
project, and open `http://login.acme.localhost:8080/apps`.
