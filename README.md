# puppet-dovecotng

Install and configure a Dovecot server.

## Usage

```puppet
class { 'dovecotng':
   # Install and pin Dovecot from Debian Backports
   use_backports => true,

   # Protocols to enable, with optional protocol settings.
   protocols => {
     'imap' => {},
     'pop3' => {},
     'lmtp' => { 'lmtp_mail_plugins' => '$mail_plugins sieve' },
   },
   plugins => ['sieve'],

   # TLS certificate and key. Both are required unless ssl is 'no'.
   ssl_cert => '/etc/ssl/certs/mail.example.com.pem',
   ssl_key  => '/etc/ssl/private/mail.example.com.key',

   # Mail location and file ownership (will use the static userdb),
   # and create the user and path.
   vmail_user  => 'vmail',
   vmail_group => 'vmail',
   vmail_path  => '/srv/mail',

   # Specify mailbox storage format and location. Alternatives to
   # Maildir include DBox, Mbox.
   mail_location => 'maildir:/srv/mail/%d/%n/Maildir',

   auth_backend => {
     'type'     => 'sql',
     'driver'   => 'mysql',
     'host'     => 'db.example.com',
     'database' => 'mail',
     'username' => 'dovecot',
     'password' => Deferred('vault_lookup::lookup', ['secret/dovecot/sql']),
   },
}
```

## Configuration changes and service refresh

Every managed configuration file notifies `dovecotng::service`, which first
checks the complete configuration with `doveconf -n`. If the check fails, the
Puppet run reports the error and Dovecot is not reloaded, so it keeps serving
its last working configuration. The broken files stay on disk, so fix them
before Dovecot is next restarted, e.g. on reboot.

With `service_refresh => 'reload'` (the default) Dovecot reloads its
configuration without dropping client connections. Set it to `'restart'` for
changes that need a full restart.

## TLS

`ssl` (`'yes'`, `'required'` or `'no'`) defaults to `'yes'`, and the catalog
fails when `ssl_cert` or `ssl_key` is missing, as Dovecot cannot serve TLS
without them. The default `ssl_cipher_list` is the Mozilla "intermediate"
profile, which allows only ECDHE/DHE key exchange with AEAD ciphers. Very old
clients that only support RSA key exchange or CBC ciphers cannot connect;
set `ssl_cipher_list` if you still need them.

## Packages

The module installs the packages the configuration needs. Packages it does not
need are left alone, unless `purge_packages => true` is set; then they are
removed, e.g. `dovecot-mysql` after switching to LDAP.

## Dovecot 2.3 and 2.4

The module supports Dovecot 2.3 (Debian 12 and earlier) and Dovecot 2.4
(Debian 13 trixie). The version is selected in this order:

1. the `dovecot_version` parameter (`'2.3'` or `'2.4'`),
2. the installed `dovecot-core` package, from the module's `dovecot_version`
   fact, e.g. when Dovecot 2.4 comes from backports or the Dovecot repository,
3. the Debian release: 13 and later use 2.4, earlier releases use 2.3.

Dovecot 2.4 changed its configuration syntax in incompatible ways. The module
renders the 2.4 syntax from the same parameters where possible:

* `mail_location` is split into `mail_driver` and `mail_path`. For values with
  extra options such as `INBOX=` or `INDEX=`, set `mail_driver`, `mail_path`
  and `mail_home` instead.
* SQL queries and the LDAP `pass_filter` must use the 2.4 `%{...}` variables.
  Dovecot 2.4 accepts the short 2.3 variables (`%u`, `%n`, `%d`, `%h`) in its
  config check but no longer expands them, so every login would fail. The module
  does not rewrite your queries. On 2.4 the Puppet run fails and suggests the
  rewritten value; on 2.3 it logs a warning with the 2.4 form.
  `%{user|username}` and `%{user|domain}` do not work on 2.3, but `%{user}` and
  `%{home}` work on both, so queries that only use `%u` or `%h` can be changed
  before upgrading. The module's default query is switched automatically.
* A simple `mail_location` is translated, including its variables, e.g.
  `maildir:%h/Maildir` becomes `mail_driver = maildir` and
  `mail_path = %{home}/Maildir`.
* The SQL and LDAP connection settings move into the main configuration. They
  are kept in the root-only files `/etc/dovecot/dovecot-sql.conf.ext` and
  `/etc/dovecot/dovecot-ldap.conf.ext`, included with `!include_try`.
* Without a `user_query`, SQL authentication uses a static userdb built from
  `vmail_user`, `vmail_group` and `vmail_path`.
* LDAP `pass_attrs` entries of the form `ldapAttr=field` become a `fields`
  block. Set `auth_backend['pass_fields']` to a Hash to provide it directly, and
  `auth_backend['starttls']` to override StartTLS, which is otherwise enabled
  unless the URIs use `ldaps://`.
* `mail_plugins` values such as `'$mail_plugins sieve'` are rendered as 2.4
  boolean lists.
* `imap_id_send` must be a Hash, e.g. `{ 'name' => 'Dovecot' }`, and
  `imap_id_log` was removed.
* `verbose_ssl` adds `category=ssl` to `log_debug`.
* The `antispam` plugin is not available for 2.4 and is no longer a default
  there. Use IMAPSieve to train a spam filter instead.

`dovecot_config_version` and `dovecot_storage_version` default to `2.4.0`.
Raise them only after reading the Dovecot upgrade notes. Once Dovecot 2.4 has
written mail storage with a storage version, downgrading to 2.3 is not supported.

### Upgrading from Debian 12 to 13

Debian's upgrade installs Dovecot 2.4 while the 2.3 configuration is still in
place, and Dovecot does not start until Puppet has written the 2.4
configuration. To keep the outage short:

1. On Dovecot 2.3, fix every warning the module logs about 2.3 variables.
   Queries that only use `%u` and `%h` can be changed to `%{user}` and
   `%{home}` right away.
2. Prepare the Dovecot 2.4 Hiera data, e.g. queries with `%{user|username}`
   and `%{user|domain}`, `imap_id_send` as a Hash and no `antispam` plugin, in a
   hierarchy level selected by `%{facts.os.distro.codename}` (`trixie`), so it
   applies as soon as the host reports Debian 13.
3. Upgrade the host, then run Puppet immediately.

The module fails the catalog rather than render a 2.4 configuration that would
silently break logins. A failed catalog changes nothing on the host, so if
the 2.4 data is incomplete, Dovecot stays down until the data is fixed.

## Authentication

`auth_backend` is a Hash with the keys documented in
`types/authbackend.pp`; unknown keys and unsupported types fail the catalog.
`auth_backend` is required, as Debian ships no SQL or LDAP connection
defaults. For SQL, `driver` is required, plus `host` and `database` for MySQL
and PostgreSQL, or `file` for SQLite.

Without a `password_query`, the module uses Dovecot 2.3's built-in default,
which Debian documents in `dovecot-sql.conf.ext`, written with the variables of
the configured Dovecot version:

```sql
-- Dovecot 2.3
SELECT username, domain, password FROM users WHERE username = '%n' AND domain = '%d'
-- Dovecot 2.4
SELECT username, domain, password FROM users WHERE username = '%{user|username}' AND domain = '%{user|domain}'
```

Without a `user_query`, SQL users share the vmail user and group, with homes
below `vmail_path/<domain>/<user>`. Set `user_query` to look users up in SQL
instead.

### Keeping credentials out of the catalog

The `password` and `bindpw` keys accept a String, a `Sensitive` or a `Deferred`:

* With `Deferred`, the agent resolves the secret and renders
  `/etc/dovecot/dovecot-sql.conf.ext` or `/etc/dovecot/dovecot-ldap.conf.ext`
  itself (`inline_epp`), so the secret never reaches the Puppet server,
  PuppetDB or reports. The deferred function must be available on the agent,
  e.g. `vault_lookup::lookup`:

  ```puppet
  'password' => Deferred('vault_lookup::lookup', ['secret/dovecot/sql']),
  ```

* Otherwise the file is rendered during compilation and its content is
  `Sensitive`, which keeps it out of reports and of the catalogs PuppetDB
  stores. A plain String password is still a class parameter in the catalog.
  To avoid that, pass the whole `auth_backend` Hash as `Sensitive`, e.g. from
  Hiera:

  ```yaml
  lookup_options:
    dovecotng::auth_backend:
      convert_to: Sensitive
  ```

Use the following for pgsql or mysql.

```puppet
   auth_backend => {
     'type'     => 'sql',
     'driver'   => 'mysql', # or pgsql
     'host'     => 'db.example.com',
     'database' => 'mail',
     'username' => 'dovecot',
     'password' => Sensitive('S3cr3t'),
     'password_query' => "SELECT password FROM users WHERE email = '%{user}'",
   }
```

On Dovecot 2.3 the SQL password must not contain whitespace, as Dovecot 2.3
cannot represent it in the connect string; Dovecot 2.4 has no such limit.

Use the following for sqlite (`host` is accepted as an alias of `file`).

```puppet
   auth_backend => {
     'type'     => 'sql',
     'driver'   => 'sqlite',
     'file'     => '/var/lib/dovecot/users.sqlite',
   }
```

Use the following for ldap.

```puppet
   auth_backend => {
     'type'        => 'ldap',
     'uris'        => 'ldap://ldap1.example.com',
     'binddn'      => 'cn=manager,o=example',
     'bindpw'      => Sensitive('S3cr3t'),
     'base'        => 'ou=mbox,o=example',
     'scope'       => 'subtree',
     'pass_filter' => '(&(mail=%{user})(objectClass=qmailUser)(accountStatus=active))'
   }
```

TLS to the LDAP server is on by default: StartTLS for `ldap://` URIs, and
implicit TLS for `ldaps://` URIs. Set `'starttls' => false` to disable
StartTLS, e.g. for a server on localhost.

### Other authentication settings

* `auth_failure_delay`: seconds to wait before answering a failed login
  (default 2, the Dovecot default).
* `auth_unix_listener_path`, `auth_unix_listener_user`,
  `auth_unix_listener_group` and `auth_unix_listener_mode`: the auth client
  socket used by login processes and e.g. Postfix SASL (default `auth-client`,
  `root`, `dovecot`, `0660`). Further listeners can be added with `services`.

## Plugins

Example antispam plugin integration with rspamd.

```puppet
class { 'dovecotng::plugin::antispam':
  # Specify arguments to antispam command
  antispam_mail_sendmail_args => '-h;localhost:11334;-P;S3cr3t',

  # Specify path to antispam command
  antispam_mail_sendmail => '/usr/bin/rspamc',

  # Specify arguments for learning spam or ham
  antispam_mail_spam    => 'learn_spam',
  antispam_mail_notspam => 'learn_ham',
}
```

## Testing

The test suite runs against OpenVox 8 and covers catalog compilation,
authentication backends, package and service management, protocol settings,
and rendered Dovecot configuration.

```sh
bundle install
bundle exec rake validate
bundle exec rake spec
```

Set `OPENVOX_GEM_VERSION` to test another supported OpenVox 8 release.

# BUGS

For bugs or feature requests, please use the GitHub issue tracker.

https://github.com/sts/puppet-dovecot/issues

# WHO

Stefan Schlesinger / sts@ono.at / @stsonoat / http://sts.ono.at
