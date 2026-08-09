# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Dashboard access

The Automator engine is **not authenticated by default**. If you mount it on a publicly reachable host, set `c.authenticate` in the initializer (HTTP basic or your app’s admin check), or constrain the mount in routes. See the README.

Treat the dashboard as an **ops console**: it can enable/disable flows, retry jobs, run sweeps, and inspect payloads.

## Automation side effects

Flows can invoke host handlers, webhooks, mailers, and attribute updates. Restrict who can create or edit rules in production, and prefer dry-run / simulate when testing. Validate or sanitize host-registered predicates and handlers as you would any application code.

Webhook destinations and notifier callables are configured by the host — protect `AUTOMATOR_WEBHOOK_URL` / related secrets and avoid logging full payloads if they contain PII.

## Multi-tenancy

Under schema-per-tenant setups, the dashboard shows the **current** tenant unless you use the read-only cross-tenant overview. Ensure `tenant_switch` cannot be abused to access schemas outside your tenancy model.

## Reporting a Vulnerability

Please report security vulnerabilities privately. Do **not** open a public issue.

- Prefer GitHub Security Advisories for [flori-s/automator](https://github.com/flori-s/automator/security/advisories/new) if available
- Or email the maintainer via the contact listed in the gemspec / GitHub profile

You can expect an initial response within **7 days**. If the report is accepted, we will work on a fix and coordinate disclosure. If declined, we will explain why.
