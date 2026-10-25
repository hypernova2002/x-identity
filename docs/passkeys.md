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
| End users | The project's verified custom domain, e.g. `login.acme.com` | Its hosted login and app portal |

Each passkey records its domain and only works there. Replacing or removing a project's custom
domain means its end users' passkeys stop working, and they add new ones on the new domain; the
Domain page says how many passkeys are affected before either.

## Adding and managing passkeys

Users add passkeys while signed in: console users on **My security**, end users on the app portal
(on the project's custom domain).
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

Admins see an end user's passkeys on their page in the console, and can remove one. An admin's
**Reset MFA** on a user removes their passkeys along with their authenticator app and
recovery codes.

Audit events: `user.passkey_added`, `user.passkey_renamed`, `user.passkey_removed` for console
users, and the same with `end_user.` for end users.

## Signing in

The console's sign-in page, and hosted login on a project's custom domain, offer passkeys two ways:
in the email field's autofill, where the browser lists the user's passkeys for the site, and with a
**Sign in with a passkey** button. No email is needed: passkeys are discoverable, so the browser
knows whose they are. A passkey sign-in records `amr` `hwk` (a device or security key) or `swk` (a
synced passkey) with `user`, updates the passkey's last use, and goes on like a password sign-in:
app access checks, an expired password isn't asked for, and the new-device email.

| Endpoint | |
| --- | --- |
| `POST /v1/accounts/:account_uid/auth/passkey/options` | Console: options for `navigator.credentials.get`, and an `authentication_id` (one use, 5 minutes) |
| `POST /v1/accounts/:account_uid/auth/passkey` | Console: the passkey's answer (`credential`) with the `authentication_id`; returns tokens, or a challenge |
| `POST …/oauth2/interactions/:interaction/passkey/options`, `…/passkey` | The same for hosted login, which then continues like a password sign-in |

Option requests are rate limited per IP address, and failed passkey sign-ins count towards the
lockout like wrong passwords.

## In your own sign-in screens

An app with its own sign-in screen, e.g. at `https://app.acme.com`, can use the project's passkeys
too, though they belong to `login.acme.com`. The custom domain publishes the app clients' allowed
origins at `https://login.acme.com/.well-known/webauthn`, and browsers that support related origins
(Chrome, Edge, Safari) then let those pages use its passkeys. Elsewhere, send users to hosted login.

1. Add the screen's origin to the app client's **Allowed origins** (its Sign-in tab).
2. Ask for options, have the browser pick a passkey, and send its answer:

```js
const api = 'https://login.acme.com/auth' // or the project's standard URL + /auth
const post = (path, body) => fetch(`${api}/${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then((r) => r.json())

const options = await post('passkey/options', { client_id })
const credential = await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options.public_key) })
const result = await post('passkey', { client_id, authentication_id: options.authentication_id, credential: credential.toJSON() })
// result: tokens, or a challenge, as with auth/sign-in
```

The same app can add passkeys for its users with `/me/passkeys` and their access token, and answer
second-factor challenges with `respond-to-challenge/passkey-options` (plus `client_id`). Passkey
sign-ins through the API check the page's origin against the domain and the app client's allowed
origins. Apps without allowed origins (native apps, server-side sign-in) don't get passkeys: their
users answer second-factor challenges with an authenticator app.

**As a second factor.** After a password, a user who has an authenticator app gets the usual `otp`
challenge; if they also have a passkey that works here (the console, hosted login on the custom
domain, or an app with allowed origins), its `mfa_methods` include `passkey`, and the
page offers **Use your passkey instead**. A user with only a passkey gets a `passkey` challenge where
the policy requires MFA; elsewhere a password alone still signs them in, as before. Answer with
`respond-to-challenge/passkey-options` (the challenge's `session`), then `respond-to-challenge` with
`challenge: passkey`, the `authentication_id` and the `credential`. Where a passkey can't be used (an
app without allowed origins, or hosted login on the standard URLs) and MFA is required, users without
an authenticator app are asked to set one up.

## Multi-factor authentication

A sign-in counts as multi-factor when it used a one-time code, or a passkey the user unlocked
(`amr` `hwk` or `swk` with `user`). That decides whether MFA is still needed, whether a refresh is
allowed under an "MFA required" policy, and the SAML authentication context sent to apps.
