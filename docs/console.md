# Console

The console is the Vue app in `web/`. Console users sign in at `/:alias/sign-in` (or `/sign-in` to
choose an account). The console remembers the last project used per account.

The **topbar** shows the account you're signed in to, an **Account settings** link and your profile
menu (profile and security, sign out). On project pages the **sidebar** starts with the project
switcher (switch project keeping the current section, see all projects, create a project) followed
by the project's pages. Account settings replace the sidebar with the account's own pages and a link
back to the project. On narrow screens the sidebar opens as a drawer from the menu button.

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

The project sidebar is grouped. Each page has its own URL, so pages can be bookmarked and shared;
pages renamed in the redesign (`app-clients`, `saml-apps`, `sign-in-providers`) redirect.

| Group | Page | What it manages | Who can change it |
| --- | --- | --- | --- |
| | Overview | Project ID, issuer, discovery and portal URLs; common tasks; a setup checklist and "needs attention" items worked out from the project's real state; failed sign-ins and access refusals in the last 24 hours, and recent events (developers). | — |
| | Applications | OpenID Connect/API clients and SAML apps in one list, searchable and filterable by type. Each app has tabs: Overview, Sign-in (redirect URIs, origins, launch URL) or Configuration (SAML), Access (group and direct assignments), Tokens & claims (OIDC), Credentials (client secret rotation, or the SAML signing certificate), Activity. | Developers (certificates: admins) |
| Directory | End users | Search by email, name or ID (`eu_…`); filters for status, email verification, MFA, group and pending invitation, kept in the URL. Each user has a page: identity and attributes, linked providers, groups and app access (including access through groups), authentication state and actions, sign out everywhere, activity. Disabling, resetting MFA, signing out and deleting are confirmed first. | Developers |
| Directory | Groups | Groups, members, and whether new users join automatically. | Developers |
| Directory | Attributes | Custom attributes: key, label, type, max length, required, user-editable, included in the ID token. Up to 50. | Project admins |
| Authentication | Settings | The project's [auth configuration](#authentication-settings), in tabs: Sign-in methods, MFA, Security policies, Tokens & sessions, Signing keys (with the JWKS URL and SAML certificates). Each tab saves only its own settings; rarely changed limits are under "Advanced". | Project admins |
| Authentication | Identity providers | Social (Google, Apple), OpenID Connect and enterprise SAML providers, grouped by kind, with the callback URL. Each provider has a page: configuration, service provider details, domains, linking and provisioning rules, group mapping, single logout, diagnostics. | Project admins |
| Monitoring & testing | Test sign-in | Signs an end user in through the public API or through hosted login, walks through challenges, and decodes the tokens, which are kept in memory only. Failures are explained without revealing whether an email is registered. Linked from each application. | Any project member |
| Monitoring & testing | Audit log | The project's events, filterable by action; links from users and apps open it pre-filtered. | Developers |
| Project settings | General | Name, self sign-up, email link templates (confirm sign-up, reset password, accept invitation). Deleting the project. | Project admins (delete: account admins) |
| Project settings | Members | Console users with a role in the project. | Project admins |

Leaving a form with unsaved changes asks for confirmation.

The console has no list of an end user's active sessions (the API doesn't provide one); "Sign out
everywhere" ends them all. SAML sign-ins are recorded against the user rather than the SAML app, so a
SAML app's Activity tab shows only configuration changes.

## Account pages

| Page | What it manages | Who can change it |
| --- | --- | --- |
| Projects | All projects you can see; creating projects. | Account admins create |
| Console users and roles | Console users, roles, disabling, invitations. | Account admins (granting owner: owners) |
| Console sign-in | The account's [auth configuration](#authentication-settings) for console users. | Account admins |
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
