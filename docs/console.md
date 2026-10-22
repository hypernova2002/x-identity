# Console

The console is the Vue app in `web/`. Console users sign in at `/:alias/sign-in` (or `/sign-in` to
choose an account). The sidebar has a **project switcher** at the top, the selected project's pages,
an **Account** section, and **My security**. The console remembers the last project used per account.

## Signing up and signing in

| Page | Purpose |
| --- | --- |
| `/sign-up` | Create an account and its first owner. |
| `/sign-in` | Enter an account alias. |
| `/:alias/sign-in` | Email and password, then any challenge: MFA code, expired password, or required MFA setup. |
| `/:alias/forgot-password`, `/:alias/reset-password` | Password reset by emailed link. |
| `/:alias/verify-email` | Email verification link, when the account requires it. |
| `/:alias/confirm-email-change` | Confirms a new email address. |
| `/:alias/accept-invitation` | Joins the account from an invitation. |

## Project pages

| Page | What it manages | Who can change it |
| --- | --- | --- |
| Overview | Name, self sign-up, email link templates (confirm sign-up, reset password, accept invitation), endpoints: issuer, OIDC discovery, JWKS, SAML metadata, app portal URL. Deleting the project. | Project admins (delete: account admins) |
| Members | Console users with a role in the project. | Project admins |
| App clients | Clients, their type, allowed origins, redirect URIs, post-logout redirect URIs and launch URL; secret rotation; enabling; **Access** (assignments). | Developers |
| SAML apps | The project's SAML identity provider details and signing certificates; SAML apps, imported from metadata or entered by hand; **Access**. | Developers (certificates: admins) |
| End users | Search, create (optionally inviting), enable/disable, reset MFA, sign out everywhere, resend invitations, delete; linked sign-in providers and groups. | Developers |
| Groups | Groups, members, and whether new users join automatically. | Developers |
| Attributes | Custom attributes: key, label, type, max length, required, user-editable, included in the ID token. Up to 50. | Project admins |
| Authentication | The project's [auth configuration](#authentication-settings). | Project admins |
| Sign-in providers | Google, Apple, OpenID Connect and SAML providers, with the callback URL and each SAML provider's service provider details. | Project admins |
| Test sign-in | Signs an end user in through the public API or through hosted login, walks through challenges, and decodes the tokens. Refresh and sign-out can be tried too. | Any project member |
| Audit log | The project's events, filterable by action. | Developers |

## Account pages

| Page | What it manages | Who can change it |
| --- | --- | --- |
| Projects | All projects you can see; creating projects. | Account admins create |
| Users | Console users, roles, disabling, invitations. | Account admins (granting owner: owners) |
| Authentication | The account's [auth configuration](#authentication-settings) for console users. | Account admins |
| Audit log | Account-level events. | Account admins |

**My security** lets each console user change their name, email and password, and set up or turn
off MFA and regenerate recovery codes.

## Authentication settings

The same settings exist for the account (console users) and each project (end users). Durations are
in seconds.

| Setting | Default | Range |
| --- | --- | --- |
| MFA requirement | optional | off, optional, required |
| Require email verification | off (account), on (projects) | |
| Password minimum length | 12 | 8–128 |
| Require uppercase / lowercase / number / symbol | off | |
| Password maximum age | none | 1–365 days |
| Lockout threshold | 10 failures | 3–100 |
| Lockout window / duration | 15 minutes each | 1 minute – 1 day |
| Access token lifetime | 15 minutes | 5–60 minutes |
| Session (refresh token) lifetime | 30 days | 1–365 days |
| Idle timeout | none | 5 minutes – 30 days |
| Signing algorithm | ES256 | ES256, RS256, PS256 |
| Signing key rotation | 90 days | 30–365 days |
| Wrong MFA codes before the user is disabled | 5 | 3–20 |
| Email code attempts per code | 5 | 3–10 |
| Email code failures per email / per code value, and window | 10 / 5, 1 hour | 3–100 / 2–100, 5 minutes – 1 day |
| OTP method | totp | totp (authenticator apps) or hotp (hardware tokens) |
| OTP digits / time step | 6 / 30 seconds | 6–10 / 30–900 seconds |
| TOTP drift / HOTP look-ahead | 1 step / 10 codes | 0–2 / 1–20 |
| Hosted login session (projects only) | 8 hours | 5 minutes – 30 days |

Changes apply from each user's next sign-in or token refresh. Changing the OTP method or format only
affects new setups; existing authenticators keep working.
