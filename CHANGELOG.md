# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-09

### Added

- Mountable Rails engine (`Automator::Engine`) with ops dashboard at `/automator`
- Flow model with triggers, conditions, cancel conditions, and actions
- Event dispatch via `Automator.trigger` and optional `Automator::Model` ActiveRecord helpers
- Change-aware triggers (`changed` / `from`–`to` filters)
- Structured condition operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `present`, `blank`, `days_before`, `days_after`
- Custom predicates and callback handlers via `Automator.register_predicate` / `register_handler`
- Built-in actions: `log`, `webhook`, `email` (host mailer + rule templates), `update_attributes`
- DB-backed `automator_jobs` queue with `rake automator:sweep` (re-check + cancel before run)
- Dry-run flows and dashboard simulate endpoint (audit outcome `test`)
- Execution audit log (`automator_executions`)
- Anomonitor-style webhooks: `c.webhook_url` or pluggable `c.notifier`
- Single-tenant default and Apartment-style multi-tenancy (`tenants` / `exclude_tenants` / `tenant_switch`)
- Cross-tenant read-only overview in the dashboard
- YAML / DSL seeding (`Automator.draw`, `rake automator:seed`)
- Install generator, migrations, and README

[0.1.0]: https://github.com/flori-s/automator/releases/tag/v0.1.0
