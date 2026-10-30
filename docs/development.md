# Development

Everything runs in Docker Compose; the host only needs Docker and Lefthook.

```bash
cp docker-compose.example.yml docker-compose.yml   # your local copy; edit ports and environment here
lefthook install                                    # git hooks, once per clone
docker compose up --build
```

| Service | Default URL | |
| --- | --- | --- |
| `backend` | http://localhost:3000 | Rails API |
| `worker` | | Background and scheduled jobs (`bin/jobs`) |
| `edge` | http://*.localhost:8080 | Serves `*.localhost` [custom domains](custom-domains.md) |
| `web` | http://localhost:5173 | Console and hosted pages |
| `yard` | http://localhost:8808 | Backend code reference |
| `mailpit` | http://localhost:8025 | Every email sent locally |
| `examples` | http://localhost:5190, http://localhost:5191 | [Example apps](examples.md) for hosted login |

Ports come from your `docker-compose.yml`, so they may differ. `db` (PostgreSQL 18) and `redis` are
only reachable from other services. Configuration is in the `environment:` blocks; there are no
`.env` files. The URLs the backend puts in tokens, emails and redirects come from `APP_BASE_URL`
and `CONSOLE_BASE_URL`.

There is no seed data: create an account at `/sign-up` in the console.

## Stack

- `backend/`: Ruby 4, Rails 8.1 (API only), PostgreSQL, Redis (rate limits and counters), Solid
  Queue, json_model_rb request models, Alba serializers, Pagy, Ransack, ruby-saml, RSpec.
- `web/`: Vue 3 with `<script setup lang="ts">`, Pinia, Vue Router, OpenVue (unstyled) with
  Tailwind, Vitest.

## Commands

The backend container defaults to `RAILS_ENV=development`; pass `-e RAILS_ENV=test` for specs.

```bash
docker compose run --rm -e RAILS_ENV=test backend bundle exec rspec
docker compose run --rm --no-deps backend bin/rubocop
docker compose run --rm --no-deps backend bin/brakeman -q
docker compose run --rm backend bin/rails db:migrate
docker compose run --rm -e RAILS_ENV=test backend bin/rails openapi_ruby:generate

docker compose run --rm --no-deps web npm run test
docker compose run --rm --no-deps web npm run check-lint
docker compose run --rm --no-deps web npm run type-check
docker compose run --rm --no-deps web npm run build-only
```

Device locations come from an offline GeoIP database (DB-IP Lite, CC BY 4.0) at
`backend/vendor/geoip/dbip-city-lite.mmdb` (or `GEOIP_DATABASE_PATH`). It isn't in git: run
`docker compose run --rm backend bin/rails geoip:download` once in development; the production image
downloads it at build, so rebuild monthly to refresh it. Without the file, locations are blank.

Background jobs run on Solid Queue, stored in the main database, in the `worker` service
(`bin/jobs`), in development as in production; specs use the test adapter. Queues are set in
`backend/config/queue.yml`: `mailers` and `default` share a worker; `maintenance` (project purges,
clearing finished jobs) has its own single thread, so slow clean-up never delays emails. Scheduled
jobs are in `backend/config/recurring.yml`. After changing job code, run
`docker compose restart worker`.

After changing `Gemfile` or `package.json`, rebuild the image (`docker compose build backend`, or
`docker compose up --build -V web`) and recreate the container with `docker compose up -d`;
`docker compose restart` keeps the old one.

The pre-commit hook runs RuboCop on staged Ruby files, the backend specs, and the frontend lint,
type check and tests.

## API reference

The request specs describe every endpoint (with openapi-ruby) and generate
`backend/openapi/public_api.yaml`. Regenerate it after changing endpoints; `api_reference_spec.rb`
fails for any route missing from it. Hosted login's interaction endpoints
(`oauth2/interactions/…`) are left out: they serve only the hosted pages. In development, Swagger
UI is served at `/api-docs` on the backend.

List endpoints share one request format, implemented by `ListQuery`: `page`, `per_page` (capped at
100), `sort=<key>` or `sort=-<key>`, `q[search]` and `q[<predicate>]` filters. Each controller
allow-lists its search, filters and sort keys; an unknown sort is a `validation_failed` error, and
rows are always ordered by `id` last. Models allow-list their searchable attributes
(`ransackable_attributes`) and associations; `ApplicationRecord` allows none by default. In the
console, list responses are validated with zod schemas (`web/src/services/schemas.ts`), and every
list uses `BaseDataTable` with `useListView`.

The audit logs and the end-user list cap their `Total` header:
- **Up to 10,000 matches:** the count is exact.
- **Beyond that:** `Total` is a lower bound and `Total-Capped: true` is set, so a page never counts a whole large table.
- **Exact count:** `exact_count=true` counts everything; the console's "Count exactly" link sends it.

Expired data is cleaned up as new rows are created, at most 100 rows per request:
- **Signing keys:** keys past their publish period are deleted when a new key is generated.
- **One-time tokens:** a subject's used and expired tokens of the same kind are deleted when a new one is issued.
- **At each new sign-in:**
  - the user's refresh tokens from expired or revoked sessions are deleted
  - hosted login sessions that ended over a day ago are deleted
  - device sessions inactive for 90 days are deleted, except the latest one

Rows belonging to users who never return stay until a scheduled cleanup is added. Audit events are never deleted.

## Code reference

Backend classes and methods are documented with YARD comments. `yard` serves them, reloading on
changes.

## Conventions

- Errors share one shape and every code is registered in `backend/app/errors/error_codes.rb`.
  Clients translate errors from codes, never from messages: an error's `code`, its `reason` when one
  code covers several cases (with `params` for names in the message), and each detail's `code` and
  `params` (e.g. `too_long` with `count`). English messages for reasons and detail codes are in
  `backend/config/locales/en.yml`; validations use codes (`errors.add(:field, :code)`,
  `message: :code`), never message strings.
- Records are exposed by prefixed uids (`HasUid`), never database ids.
- Request bodies are parsed by request models in `backend/app/request_models/`, which reject unknown
  fields; controllers pass the fields to services as keyword arguments. Every field has a
  description and every string, array and hash a maximum size. Objects with known fields are
  nested request models (e.g. `Passkeys::AssertionCredentialRequest`). Field types used by more than one
  resource are in `RequestTypes`; those a resource's requests share (such as create and update) are
  in its `Fields` module, e.g. `SamlApps::Fields`. Limits use the model's constant where there is
  one. Optional text fields reject `""`; `null` clears them.
- Services take plain arguments (including `ip` and `user_agent` for auditing) and never touch the
  request.
- Sign-in logic is shared between console users and end users through realms.
- A write whose result depends on what's already stored (merging values, rules across fields or
  rows) locks the resource's main row with `lock!` or `with_lock` inside its transaction, then
  reads, validates and saves. Locking reloads the row, so the write never builds on a copy loaded
  before another request's change. Use a transaction-scoped advisory lock only when there's no row
  to lock yet.
- A change's audit event is recorded inside the transaction that makes the change, so they commit
  together. Events about failures and refusals (a wrong code, a blocked request) are recorded
  outside any transaction that will roll back, because the request is about to fail. Jobs and
  emails are enqueued after the transaction commits.
- The frontend reaches the API through `web/src/services/`; design tokens are in
  `web/src/assets/tokens.css`, and feature code uses the wrappers in `web/src/components/base/`.
- Frontend text is in `web/src/locales/<locale>/`, through vue-i18n (`$t` in templates, `<i18n-t>`
  for sentences with links or markup, `i18n.global.t` outside components). Signed-in users'
  language is their `locale` (console users and end users), saved when they pick one in the
  language switcher; signed out, the choice is kept in `localStorage`. A user with no `locale` sees
  the browser's language, falling back to English. To add a language, add its messages and flag
  (`LanguageFlag.vue`), list it in `SUPPORTED_LOCALES` (`web/src/i18n/index.ts`) and in
  `HasLocale::LOCALES` on the backend. `ApiError` builds its message from the error's
  code, reason and details (`errors` messages), never from the API's English. ESLint's
  `vue/no-bare-strings-in-template` rejects untranslated text in templates.
