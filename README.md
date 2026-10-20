# x-identity

User directories and authentication for accounts and their projects.

- `backend/` — Rails API (Ruby 4.0, Rails 8.1, PostgreSQL, Redis)
- `web/` — Vue 3 + TypeScript console (Vite, Pinia, Vue Router, OpenVue unstyled, Tailwind)

Everything runs in Docker; nothing needs to be installed on the host except Docker and Lefthook.

## Getting started

```bash
cp docker-compose.example.yml docker-compose.yml   # your local copy; edit ports/env here
lefthook install                                    # once per clone
docker compose up --build
```

| Service   | URL                     |
| --------- | ----------------------- |
| `backend` | http://localhost:3000   |
| `web`     | http://localhost:5173   |
| `yard`    | http://localhost:8808   |
| `mailpit` | http://localhost:8025   |

`db` (Postgres 18) and `redis` are only reachable from other services.

Configuration lives in the `environment:` blocks of `docker-compose.yml`; there are no `.env` files.

## Using the console

1. Open http://localhost:5173/sign-up and create an account. The account alias becomes part of your sign-in URL (`/acme/sign-in`).
2. You're signed in and asked to create your first project.
3. Verification, password reset and invitation emails land in Mailpit at http://localhost:8025.

Email verification is off by default. Turn it on per account under **Authentication** in the console.

## Common commands

```bash
docker compose run --rm backend bundle exec rspec
docker compose run --rm --no-deps backend bundle exec rubocop
docker compose run --rm backend bin/rails db:migrate
docker compose run --rm backend bin/rails openapi_ruby:generate

docker compose run --rm --no-deps web npm run test
docker compose run --rm --no-deps web npm run check-lint
docker compose run --rm --no-deps web npm run type-check
```

After changing `Gemfile` or `package.json`, rebuild: `docker compose build backend` / `docker compose up --build -V web`.

## Conventions

- API errors share one shape, `{ "error": { "code", "message", "details": [{ "field", "message" }] } }`. Every code is registered in `backend/app/errors/error_codes.rb`.
- Records are exposed by prefixed `uid` (see `HasUid`), never by database id.
- Request bodies are parsed by typed request models in `backend/app/requests/` (json_model_rb). Controllers pass their fields to services as keyword arguments, and request specs document each body with `SomeRequest.as_schema`.
- Allowed browser origins are set with `CORS_ALLOWED_ORIGINS` (comma-separated).
- Accounts are fully isolated: users, signing keys, token issuer, lockout counters and audit events are all per account, and the same email can exist in several accounts as separate users. Everything after sign-up lives under `/v1/accounts/:account_uid/`.
- A user's identity is their `uid` (the token `sub`); email is only a sign-in identifier and can change.
- Design tokens live in `web/src/assets/tokens.css`; feature code uses the wrappers in `web/src/components/base/`.
