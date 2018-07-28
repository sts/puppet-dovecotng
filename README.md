# puppet-dovecotng

Install and configure a Dovecot server.

## Usage

```puppet
class { 'dovecotng':
   # Install and pin Dovecot from Debian Backports
   use_backports => true,

   # Start protocol listeners for imap(s), pop3(s), sieve and managesieve.
   protocols => ['imap', 'pop3', 'sieve'],

   # SSL Configuration - requires a concatenated ssl cert file in
   # /etc/ssl/$domain.pem
   ssl_cert => "example.com",
   ssl_protocols => "!SSLv2",
   ssl_cipher_list => "ALL:!LOW:!SSLv2:!EXP:!aNULL",

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
     'host'     => 'localhost',
     'database' => 'smailr',
     'username' => 'smailr',
     'password' => 'smailr',
     'password_query' => 'SELECT CONCAT(mailboxes.password_scheme, mailboxes.password) AS password, \
              mailboxes.localpart AS username, \
              domains.fqdn AS domain \
              FROM mailboxes, domains \
              WHERE mailboxes.localpart = '%n' \
              AND domains.fqdn = '%d' \
              AND domains.id = mailboxes.domain_id',
   },

}
```

## Authentication

The puppet module assumes you will always use a static userdb, values for mail
storage and user id/group id are derived from the vmail_* attributes.

Use the following for pgsql or mysql.

```puppet
   auth_backend => {
     'type'     => 'sql',
     'driver'   => 'mysql', # or pgsql
     'host'     => 'localhost',
     'database' => 'smailr',
     'username' => 'smailr',
     'password' => 'S3cr3t',
     'password_query => 'SELECT CONCAT(mailboxes.password_scheme, mailboxes.password) AS password, \
              mailboxes.localpart AS username, \
              domains.fqdn AS domain \
              FROM mailboxes, domains \
              WHERE mailboxes.localpart = '%n' \
              AND domains.fqdn = '%d' \
              AND domains.id = mailboxes.domain_id',

   }
```

Use the following for sqlite.

```puppet
   auth_backend => {
     'type'     => 'sql',
     'driver'   => 'sqlite',
     'host'     => '/etc/smailr/users.sqlite',
   }
```

Use the following for ldap.

```puppet
   auth_backend => {
     'type'        => 'ldap',
     'uris'        => 'ldaps://ldap1.example.com',
     'binddn'      => 'cn=manager,o=example',
     'bindpw'      => 'S3cr3t',
     'base'        => 'ou=mbox,o=example',
     'scope'       => 'subtree',
     'pass_filter' => '(&(mail=%u)(objectClass=qmailUser)(accountStatus=active))'
   }
```

## Plugins

Example antispam plugin integration with rspamd.

```puppet
class { 'dovecot::plugin::antispam':
  # Specify arguments to antispam command
  antispam_mail_sendmail_args = '-h;localhost:11334;-P;S3cr3t'

  # Specify path to antispam command
  antispam_mail_sendmail = '/usr/bin/rspamc',

  # Specify arguments for learning spam or ham
  antispam_mail_spam = 'learn_spam',
  antispam_mail_notspam = 'learn_ham',
}
```

# BUGS

For bugs or feature requests, please use the GitHub issue tracker.

https://github.com/sts/puppet-dovecot/issues

# WHO

Stefan Schlesinger / sts@ono.at / @stsonoat / http://sts.ono.at
