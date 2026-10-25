# Passkeys

A passkey is a key pair: the private key stays on the user's device or in their password manager,
and x-identity keeps only the public key. Signing in with one needs the user to unlock their device
(fingerprint, face or device PIN), so a passkey proves possession and the user at once, and can't
be phished: browsers only offer it on the site it was made for.

## Turning passkeys on

Passkeys are off by default. Turn them on with **Passkeys: Optional**:

- for console users, in the account's **Console sign-in** settings;
- for a project's end users, in its **Authentication › Sign-in methods**. A project also needs a
  verified [custom domain](custom-domains.md): its end users' passkeys belong to that domain.

Turning passkeys off stops users adding them; existing ones are listed and can still be removed.

## Where passkeys belong

| Users | Passkeys belong to | Added and used on |
| --- | --- | --- |
| Console users | The console's host (`CONSOLE_BASE_URL`) | The console |
| End users | The project's verified custom domain, e.g. `login.acme.com` | That domain |

Each passkey records its domain and only works there. Replacing or removing a project's custom
domain means its end users' passkeys stop working, and they add new ones on the new domain.

## Adding and managing passkeys

Users add passkeys while signed in: console users on **My security**, end users through the API on
the project's custom domain.
Adding one needs a sign-in in the last 15 minutes, since a passkey is a new way into the account;
otherwise the page asks them to sign in again. A passkey is named after the browser and device it
was added on (e.g. "Chrome on Mac"), and can be renamed. Passkeys that sync through a password
manager are marked **Synced**.

The API, for console users under `/v1/accounts/:account_uid/me` and for end users under a
project's `/me` on its custom domain:

| Endpoint | |
| --- | --- |
| `GET passkeys` | The user's passkeys |
| `POST passkeys/options` | Options for `navigator.credentials.create`, and a `registration_id` (one use, 5 minutes) |
| `POST passkeys` | The created passkey (`credential`, its JSON) with the `registration_id`, and optionally a `name` |
| `PATCH passkeys/:uid` | Rename |
| `DELETE passkeys/:uid` | Remove |

New passkeys must be discoverable and verify the user (`residentKey` and `userVerification`
required); attestation isn't requested.

An admin's **Reset MFA** on a user removes their passkeys along with their authenticator app and
recovery codes.

Audit events: `user.passkey_added`, `user.passkey_renamed`, `user.passkey_removed` for console
users, and the same with `end_user.` for end users.

## Multi-factor authentication

A sign-in counts as multi-factor when it used a one-time code, or a passkey the user unlocked
(`amr` `hwk` or `swk` with `user`). That decides whether MFA is still needed, whether a refresh is
allowed under an "MFA required" policy, and the SAML authentication context sent to apps.
