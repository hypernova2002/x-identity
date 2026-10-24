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

After changing `Gemfile` or `package.json`, rebuild the image (`docker compose build backend`, or
`docker compose up --build -V web`) and recreate the container with `docker compose up -d`;
`docker compose restart` keeps the old one.

The pre-commit hook runs RuboCop on staged Ruby files, the backend specs, and the frontend lint,
type check and tests.

## API reference

The request specs describe every endpoint (with openapi-ruby) and generate
`backend/openapi/public_api.yaml`. Regenerate it after changing endpoints. In development, Swagger
UI is served at `/api-docs` on the backend.

List endpoints share one request format, implemented by `ListQuery`: `page`, `per_page` (capped at
100), `sort=<key>` or `sort=-<key>`, `q[search]` and `q[<predicate>]` filters. Each controller
allow-lists its search, filters and sort keys; an unknown sort is a `validation_failed` error, and
rows are always ordered by `id` last. Models allow-list their searchable attributes
(`ransackable_attributes`) and associations; `ApplicationRecord` allows none by default. In the
console, list responses are validated with zod schemas (`web/src/services/schemas.ts`), and every
list uses `BaseDataTable` with `useListView`.

## Code reference

Backend classes and methods are documented with YARD comments. `yard` serves them, reloading on
changes.

## Conventions

- Errors share one shape and every code is registered in `backend/app/errors/error_codes.rb`.
- Records are exposed by prefixed uids (`HasUid`), never database ids.
- Request bodies are parsed by request models in `backend/app/request_models/`, which reject unknown
  fields; controllers pass the fields to services as keyword arguments.
- Services take plain arguments (including `ip` and `user_agent` for auditing) and never touch the
  request.
- Sign-in logic is shared between console users and end users through realms.
- The frontend reaches the API through `web/src/services/`; design tokens are in
  `web/src/assets/tokens.css`, and feature code uses the wrappers in `web/src/components/base/`.
