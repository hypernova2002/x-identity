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

Email verification is off by default for console users. Turn it on per account under **Authentication** in the console.

## Signing in a project's end users

Each project is its own user pool with its own settings, signing keys and audit log. To sign end users in from your app:

1. In the project, create an **app client** (public for browser and mobile apps, confidential for server-side apps). Add your web app's origin to its allowed origins.
2. Call the project's auth API with the client's uid as `client_id`. The base URL is shown on the project's Overview tab: `/v1/accounts/:account_uid/projects/:project_uid`.

```bash
BASE=http://localhost:3000/v1/accounts/$ACCOUNT_UID/projects/$PROJECT_UID
curl -X POST $BASE/auth/sign-up -H 'Content-Type: application/json' \
  -d '{"client_id":"cl_…","email":"casey@shop.test","password":"correct horse battery staple"}'      # 202
curl -X POST $BASE/auth/confirm-sign-up -H 'Content-Type: application/json' \
  -d '{"client_id":"cl_…","email":"casey@shop.test","code":"123456"}'                              # code from the email
curl -X POST $BASE/auth/sign-in -H 'Content-Type: application/json' \
  -d '{"client_id":"cl_…","email":"casey@shop.test","password":"correct horse battery staple"}'      # access, ID and refresh tokens
```

Verify access tokens against `$BASE/.well-known/jwks.json`: the `aud` is the app client's uid and `iss` is `$BASE`.

Responses never reveal whether an email is registered: sign-up, resend-confirmation and forgot-password always return `202`, and the lookup happens in a background job.

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
- Request bodies are parsed by typed request models in `backend/app/request_models/` (json_model_rb), which reject unknown keys. Controllers parse with `parse_request` and pass the fields to services as keyword arguments; request specs document each body with `SomeRequest.as_schema`.
- Sign-in logic is shared between console users and end users through realms (`Realms::AccountRealm`, `Realms::ProjectRealm`).
- Allowed browser origins are set with `CORS_ALLOWED_ORIGINS` (comma-separated).
- Accounts are fully isolated: users, signing keys, token issuer, lockout counters and audit events are all per account, and the same email can exist in several accounts as separate users. Everything after sign-up lives under `/v1/accounts/:account_uid/`.
- A user's identity is their `uid` (the token `sub`); email is only a sign-in identifier and can change.
- Design tokens live in `web/src/assets/tokens.css`; feature code uses the wrappers in `web/src/components/base/`.
