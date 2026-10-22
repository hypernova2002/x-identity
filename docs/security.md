# Security model

## No user enumeration

Responses never reveal whether an email is registered:

- Sign-up, resend confirmation and forgot password always return `202`. The lookup happens in a
  background job, which emails the right message (a code, or "you already have an account").
- Email change sends its code from a background job too, so it doesn't reveal whether the new
  address is taken.
- Wrong passwords, unknown emails and disabled users all get the same `invalid_credentials`.
- Home realm discovery asks the server per email; the list of SAML domains is never published.

Errors that do say more (`email_not_verified`, `provider_email_unverified`, linking conflicts)
only appear after the caller has proven the password or proven ownership of the email through an
identity provider.

## Passwords and lockouts

- Passwords are hashed with Argon2id, with a unique random salt each.
- Password rules (length, character classes, maximum age) are configurable per account and project.
- After the configured number of failures for an email within the window (10 in 15 minutes by
  default), that email is locked for the lockout duration (`429 too_many_attempts`). Counters are
  per account or project.

## Multi-factor authentication

Consecutive wrong MFA codes disable the user after the configured limit, except the last active
account owner, who is locked out temporarily instead. See [MFA](end-user-auth/mfa.md).

## Email codes

Email codes are 6 digits, HMAC-hashed at rest, and expire. They're limited three ways within the
failure window:

- **per code**: a few wrong guesses and that code stops working;
- **per email**: too many failures and codes for that address are refused for a while;
- **per code value**: a value guessed wrongly against many addresses is blocked, which stops one
  guess being tried across many accounts. New codes skip blocked values.

Links carry a separate opaque token.

## Sessions and tokens

- Access tokens are short-lived JWTs (15 minutes by default, at most an hour), bound to one app
  client (`aud`) and one issuer.
- Refresh tokens are opaque, stored as digests, and rotate on every use. Reusing one revokes the
  whole session family and is audited.
- Revoking a user's sessions (sign out everywhere, password reset, disabling) invalidates their
  refresh tokens, outstanding access tokens and hosted login sessions.
- Changing a password or email signs out the user's other sessions.
- Sign-in challenge sessions last 5 minutes and are bound to the app client and, for hosted login,
  the interaction.

## OAuth and OpenID Connect

- PKCE (S256) is required for every client, including confidential ones.
- Redirect URIs and post-logout redirect URIs are matched exactly; plain http is only allowed on
  loopback addresses; custom schemes are allowed for native apps (`javascript:`, `data:` and similar
  are refused).
- Authorization codes last one minute and work once; interactions last 30 minutes.
- The hosted login page never receives tokens or client secrets.
- The single sign-on cookie is httpOnly, SameSite=Lax, scoped to the project's path, and Secure
  when the API is served over https.

## Identity providers

- ID tokens are verified against the provider's keys, issuer, audience, expiry and a nonce.
- Emails are only trusted when the provider says they're verified; SAML providers are only trusted
  for their listed domains.
- Existing users are only linked when their email is verified (or they're invited with no password),
  which stops pre-registered accounts from being taken over.
- SAML responses are validated with ruby-saml's service provider checks, each assertion is accepted
  once, and logout requests from an IdP must be signed by it.

## SAML messages

Incoming XML is parsed without network access, without document types (so no entity expansion), and
with a 256 KB limit. Signed requests are checked against the exact bytes received. Responses are
delivered to registered ACS URLs only.

## Outgoing requests

Requests to identity providers (discovery, keys, token exchange, metadata URLs) only go to https
URLs, with timeouts and a size limit. Hosts that resolve to private, loopback or link-local addresses
are refused, and the connection goes to the address that was checked, so admin-entered URLs can't be
used to reach internal services.

## Keys and secrets

- Token signing keys rotate automatically; retired keys stay published until their tokens expire.
- SAML certificates rotate in three steps (next, active, retired).
- Confidential client secrets are stored as SHA-256 digests and shown once.
- Identity provider secrets, Apple private keys, OTP secrets and SAML private keys are encrypted with
  Active Record Encryption.

## Rate limits

Per IP, with `429 rate_limited` and `Retry-After`:

| Scope | Limit |
| --- | --- |
| Every request | 300 per 5 minutes |
| Account sign-up | 10 per hour |
| Account lookup | 30 per minute |
| Console auth (POST) | 30 per minute; 5 per minute for forgot password and resend confirmation |
| Project auth (POST) | 60 per minute; 10 per minute for sign-up, resend confirmation and forgot password; 20 per minute for code confirmations |
| Provider redirects (GET) | 30 per minute |
| OAuth endpoints | 60 per minute; 10 and 20 per minute for the hosted page's email and code actions |
| SAML sign-on, logout and SP endpoints | 60 per minute |

## CORS

Browsers can call the API from the console's origins (`CORS_ALLOWED_ORIGINS`) and from origins
listed on enabled app clients. CORS only restricts browsers; every request is still authenticated
and authorised.

## Audit logs

Accounts and projects record sign-ins, failures, MFA changes, token reuse, admin changes, provider
and app configuration, assignments, group changes and access refusals, with the actor, target, IP,
user agent and app client.
