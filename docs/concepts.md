# Concepts

## Accounts

An **account** is an organisation using x-identity. It is created through self-service sign-up
(`POST /v1/sign-up`) with a name and an **alias** (slug): 3–40 lowercase letters, numbers and
hyphens, unique, and not one of the reserved words (`sign-in`, `sign-up`, `console`, `admin`, `api`,
`app`, `auth`, `help`, `login`, `logout`, `settings`, `support`, `www`).

Accounts are fully isolated. Each has its own console users, signing keys, token issuer, lockout
counters, auth configuration and audit log. The same email can exist in several accounts as
unrelated users. Everything after sign-up lives under `/v1/accounts/:account_uid/`.

## Console users and roles

**Console users** (`User`) manage an account in the console. Each has an account role:

| Role | Can |
| --- | --- |
| owner | Everything, including granting the owner role. An account always keeps at least one active owner. |
| admin | Manage users, invitations, account settings and every project, but not grant the owner role. |
| member | Only see the projects they're a member of. |

Within a project, members (who aren't account owners or admins) have a **project role**:

| Project role | Can |
| --- | --- |
| admin | Everything in the project: settings, members, providers, certificates, attributes. |
| developer | Manage app clients, SAML apps, end users, groups and assignments; read the audit log. |
| viewer | Look only. |

Account owners and admins act as project admins in every project. Only account owners and admins can
create or delete projects.

## Projects

A **project** is an isolated directory of end users, usually one per environment or product
(Production, Staging). It has its own:

- end users, groups and custom attributes,
- app clients and SAML apps,
- auth configuration (passwords, MFA, lockouts, tokens),
- signing keys and SAML certificates,
- identity providers,
- audit log.

A project's **issuer** is its base URL, `…/v1/accounts/:account_uid/projects/:project_uid`. It is
the `iss` of its tokens, the OpenID Connect issuer, and the prefix of its SAML entity IDs.

## End users

**End users** (`EndUser`) are the people who sign in to your apps. They're identified by their
`uid` (the token `sub`); email is a sign-in identifier that can change. An end user may have a
password, linked identity provider accounts, or both. Users created by an admin or invited have no
password until they accept the invitation.

## App clients

An **app client** is one app that signs end users in. Its `uid` is the OAuth `client_id`.

- **Public** clients (browser, mobile) have no secret.
- **Confidential** clients (server-side) have a secret, shown once at creation or rotation.

Settings: allowed browser origins (CORS), redirect URIs (for provider sign-in and hosted login),
post-logout redirect URIs, and a launch URL for the app portal. Disabling or deleting a client signs
out every session started through it. Nobody can sign in through a client until it's assigned to
them (see [Groups and app access](groups-and-access.md)).

Each project also has a system-managed **app portal** client, hidden from the app clients list.

## Realms

Sign-in logic is shared between console users and end users through **realms**: the account realm
(console users) and a project realm (that project's end users). A realm supplies the users, the
auth configuration, the signing keys, the token issuer and the audit log. Console sign-in lives
under `/v1/accounts/:account_uid/auth/…`, end-user sign-in under `…/projects/:project_uid/auth/…`.

## Tokens

Successful sign-ins return:

- an **access token**: a signed JWT (`token_use: access`) with `iss`, `sub`, `aud` (the app client's
  uid for end users), `exp`, `auth_time`, `amr` (how the user authenticated, e.g. `pwd`, `otp`,
  `fed`), `sid` (the session) and `client_id`;
- an **ID token** for end users: `email`, `email_verified`, `name`, custom attributes marked for
  the token, and `groups` when the `groups` scope was requested;
- a **refresh token**: opaque, rotated on every use. Reusing an old one revokes the whole session.

Tokens are signed with the realm's current key (ES256 by default; RS256 and PS256 are available)
and can be verified against `…/.well-known/jwks.json`. Keys rotate automatically (every 90 days by
default); retired keys stay published until every token they signed has expired.

## Identifiers and errors

Records are exposed by prefixed uids (`acct_`, `proj_`, `eu_`, `cl_`, `grp_`, `idp_`, `saml_`…),
never by database ids.

API errors share one shape:

```json
{ "error": { "code": "validation_failed", "message": "One or more fields are invalid.", "details": [{ "field": "email", "message": "is required" }] } }
```

Every code is listed in `backend/app/errors/error_codes.rb` and in the OpenAPI document. The OAuth
2.0 endpoints (`/oauth2/…`) use the OAuth error format instead (`error`, `error_description`),
because OpenID Connect libraries expect it.
