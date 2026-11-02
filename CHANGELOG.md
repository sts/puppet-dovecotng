# Changelog

All notable changes to this module are documented in this file. The module
follows [Semantic Versioning](https://semver.org/).

## 1.0.0

Adds support for Dovecot 2.4 (Debian 13 trixie) next to Dovecot 2.3, and
reworks defaults, credentials handling and service refreshes. Read the
breaking changes before upgrading.

### Breaking changes

- `auth_backend` is required. The defaults for the smailr schema (MySQL on
  `localhost`, database, user and password `smailr`, and the smailr password
  query) were removed, as Debian ships no SQL or LDAP connection defaults. For
  SQL, `driver` is required, plus `host` and `database` for MySQL and
  PostgreSQL, or `file` for SQLite.
- Without a `password_query`, the Dovecot default query is used:
  `SELECT username, domain, password FROM users WHERE username = '%n' AND domain = '%d'`
  (with `%{user|username}` and `%{user|domain}` on Dovecot 2.4). Set
  `password_query` to keep a custom schema.
- `auth_backend` is validated against `Dovecotng::AuthBackend`. Unknown keys
  and backend types other than `sql` and `ldap` fail the catalog.
- With `ssl` enabled (the default), `ssl_cert` and `ssl_key` are required.
  Previously Dovecot 2.3 refused to start without them. Set `ssl => 'no'` to
  run without TLS.
- The default `ssl_cipher_list` is now the Mozilla "intermediate" profile
  (ECDHE/DHE key exchange with AEAD ciphers only). Clients that only support
  RSA key exchange or CBC ciphers can no longer connect unless
  `ssl_cipher_list` is set.
- Packages the configuration does not need are no longer removed. Set
  `purge_packages => true` to remove them as before.
- On Dovecot 2.3 without a `user_query`, SQL authentication uses a static
  userdb built from `vmail_user`, `vmail_group` and `vmail_path` instead of an
  SQL userdb with an empty query.
- On Dovecot 2.3 the SQL password must not contain whitespace, which Dovecot
  2.3 cannot represent in the connect string.
- The legacy, non-namespaced `bool2dovecot()` function was removed. Use
  `dovecotng::bool2dovecot()`.
- `dovecotng::bool2dovecot()` only treats the exact strings `true` and `false`
  (any case) as booleans. Other strings containing these words pass through
  unchanged.
- `auth_unix_listener_user` and `auth_unix_listener_group` default to `root`
  and `dovecot`, the values the auth client listener was always rendered with.
  The parameters were previously ignored.
- `auth_failure_delay` is now rendered and defaults to 2 seconds, the Dovecot
  default. It was previously ignored.
- The credential files `dovecot-sql.conf.ext` and `dovecot-ldap.conf.ext`
  are rendered from new templates without Dovecot's example comments.

### Added

- Dovecot 2.4 support. The version is taken from the `dovecot_version`
  parameter, else from the installed package (new `dovecot_version` fact), else
  from the Debian release (13 and later use 2.4).
- Dovecot 2.4 configuration: `mail_driver`, `mail_path` and `mail_home`
  (translated from a simple `mail_location`), the new SQL and LDAP passdb and
  userdb blocks, the renamed authentication, SSL and logging settings,
  `mail_plugins` boolean lists, and the Pigeonhole 2.4 sieve settings.
- SQL queries and the LDAP `pass_filter` are checked for the Dovecot 2.3
  variables (`%u`, `%n`, `%d`, `%h`), which Dovecot 2.4 no longer expands. On
  2.4 the catalog fails with a suggested rewrite; on 2.3 a warning shows the
  2.4 form.
- `password` and `bindpw` accept `Sensitive` and `Deferred` values. With
  `Deferred`, the agent renders the credential file, so the secret never
  enters the catalog. The whole `auth_backend` can be passed as `Sensitive`.
- `ssl` parameter (`yes`, `required` or `no`).
- `service_refresh` parameter (`reload` or `restart`).
- `purge_packages` parameter.
- `auth_backend['starttls']` to disable StartTLS for LDAP.
- README sections for the Dovecot 2.4 changes and the upgrade from Debian 12
  to 13.

### Changed

- Configuration changes are checked with `doveconf -n` before Dovecot is
  refreshed, and Dovecot is reloaded instead of restarted, so client
  connections are kept. If the check fails, the refresh is skipped.
- The credential files are rendered as `Sensitive` content.
- LDAP uses TLS by default on Dovecot 2.3 and 2.4: StartTLS for `ldap://`
  URIs, implicit TLS for `ldaps://` URIs. Dovecot 2.3 previously always used
  StartTLS, which failed with `ldaps://` URIs.
- `auth_backend` keys that are not set fall back to the defaults of the
  backend type.
- PostgreSQL passwords are quoted in the Dovecot 2.3 connect string.

### Fixed

- `pop3_mail_plugins` was rendered as the invalid setting `pop3_mail_plugins`
  instead of `mail_plugins`.
- The sieve precompile exec failed on the first run when sieve was disabled,
  and never recompiled changed scripts. It now only runs when sieve is enabled
  and a script is newer than its compiled binary.
- The stats-writer listener uses `vmail_group`.
- Changes to the IMAP, POP3 and LMTP protocol settings now refresh Dovecot.
- The SQLite example in the README used `host`; `file` is now documented, and
  `host` is accepted as an alias.
- Variable references no longer use the deprecated top-scope `$::` prefix.
