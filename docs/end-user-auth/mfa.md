# Multi-factor authentication

[Passkeys](../passkeys.md) count as multi-factor authentication too: a passkey sign-in needs no code, and a passkey can answer the code challenge.

MFA works the same way for console users (account settings) and end users (project settings).

## Methods

Each account and project uses **one** method, chosen in its authentication settings:

- **TOTP**: time-based codes from authenticator apps (Google Authenticator, 1Password, Authy…).
- **HOTP**: counter-based codes, mostly from hardware tokens.

Digits (6–10), the TOTP step (30–900 seconds), the TOTP drift tolerance and the HOTP look-ahead are
configurable. Each user's credential keeps the method and format it was set up with, so changing
the settings doesn't break existing authenticators. Many authenticator apps only support 6 digits
and 30 seconds.

## Requirement

| Setting | Behaviour |
| --- | --- |
| off | Codes are never asked for, even from users who set MFA up. |
| optional | Users choose. Those with MFA get the `otp` challenge at sign-in. |
| required | Users without MFA get the `mfa_setup` challenge at sign-in, and can't turn MFA off. Sessions started without MFA can't be refreshed. |

## Setting up and turning off

1. Start: `POST me/otp` (or the `mfa_setup` challenge's `POST auth/mfa-setup`) returns the secret,
   an `otpauth://` URI and a QR code.
2. Confirm with a code: `POST me/otp/confirm` (or answer the `mfa_setup` challenge). This turns MFA
   on and returns 10 **recovery codes**, each usable once instead of an authenticator code.
3. Turn off with `DELETE me/otp` and the current password plus a code, unless the policy requires
   MFA. Recovery codes can be regenerated with `POST me/recovery-codes`.

Admins can reset an end user's MFA from the console, for example after a lost phone.

## Failure handling

Consecutive wrong codes count per user. After the configured limit (5 by default), the user is
**disabled** and told by email; an admin re-enables them. The one exception is the last active
owner of an account, who is locked out temporarily instead, so an account can't lock itself out.
Wrong codes also count towards the sign-in lockout.

Codes entered while confirming a new setup don't count: the user is still setting up.

## In tokens

`amr` records how the user signed in: `pwd` (password), `fed` (an identity provider), `otp`
(a code). SAML assertions report MFA with the `https://refeds.org/profile/mfa` context.
