# Custom domains

A project can have its own domain, such as `login.acme.com`, for its hosted login and endpoints.
Admins add it on the project's **Custom domain** page. Nothing changes for existing apps when a
domain is added or verified: they keep using the project's standard URLs until they're switched.

## Verifying a domain

Use a subdomain you control. The console shows two DNS records to create at its DNS provider:

| Type | Name | Value |
| --- | --- | --- |
| CNAME | `login.acme.com` | the platform's target (`CUSTOM_DOMAIN_TARGET`) |
| TXT | `_x-identity.login.acme.com` | the domain's verification token |

The TXT record proves the project's owner controls the domain; the CNAME points it at x-identity.
A background job checks both, starting a minute after the domain is added and backing off to
hourly, for up to 72 hours; **Check now** checks straight away. Each check shows what's wrong, for
example a CNAME pointing elsewhere. A domain still unverified after 72 hours is marked failed;
fix the records and check again, or remove it.

A domain can only be used by one project. x-identity's own hosts and their subdomains can't be
used.

## Keeping and replacing a domain

Keep both records while the domain is in use. Verified domains are re-checked hourly; if their
records disappear the domain stays in use, but the console flags it and shows since when.

A project has one domain in use and can set up one replacement at a time. The replacement is
checked while the current domain keeps working, and takes over once it's verified.

Audit events: `domain.added`, `domain.verified`, `domain.failed` and `domain.removed` (with
`replaced_by` when a replacement took over).

## Certificates

HTTPS certificates for custom domains are issued outside x-identity, by the proxy in front of it.
Before issuing one, the proxy can ask whether a hostname is a verified domain of an active project:

```
GET /internal/domains/allowed?domain=login.acme.com   → 200 if verified, 404 otherwise
```

This is the shape Caddy's on-demand TLS `ask` option expects. The endpoint is rate limited and
reveals nothing beyond whether the domain is verified.

## Configuration

| Variable | Default | |
| --- | --- | --- |
| `CUSTOM_DOMAIN_TARGET` | `domains.x-identity.localhost` | The hostname customers' CNAME records point at |

In development, `*.localhost` domains (e.g. `login.acme.localhost`) verify without DNS, since
browsers resolve them to your machine. They're refused in production.
