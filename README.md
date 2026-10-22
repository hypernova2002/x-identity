# x-identity

User directories and authentication for accounts and their projects: a sign-in API, hosted login,
an OpenID Connect provider, a SAML identity provider, social and SAML federation, MFA, groups and
assignment-only app access.

- `backend/`: Rails API (Ruby 4.0, Rails 8.1, PostgreSQL, Redis)
- `web/`: Vue 3 + TypeScript console and hosted pages (Vite, Pinia, Vue Router, OpenVue unstyled, Tailwind)

## Getting started

Everything runs in Docker; the host only needs Docker and Lefthook.

```bash
cp docker-compose.example.yml docker-compose.yml   # your local copy; edit ports/env here
lefthook install                                    # once per clone
docker compose up --build
```

Open the console (http://localhost:5173 by default), create an account at `/sign-up`, and create
your first project. Emails land in Mailpit (http://localhost:8025).

## Documentation

See [`docs/`](docs/README.md) for the feature overview, concepts, the console, the end-user sign-in
API, MFA, identity providers, hosted login and OpenID Connect, groups and app access, SAML apps and
the app portal, the security model, and development (commands, checks, API reference, YARD).
