class dovecotng::install
{
  $auth = $dovecotng::_auth_backend

  # Packages and whether the configuration needs them.
  $packages = {
    'dovecot-core'         => true,

    # Protocols
    'dovecot-imapd'        => 'imap' in $dovecotng::protocols,
    'dovecot-pop3d'        => 'pop3' in $dovecotng::protocols,
    'dovecot-lmtpd'        => 'lmtp' in $dovecotng::protocols,
    'dovecot-managesieved' => 'sieve' in $dovecotng::protocols,

    # Plugins
    'dovecot-sieve'        => 'sieve' in $dovecotng::_plugins,
    'dovecot-antispam'     => 'antispam' in $dovecotng::_plugins,

    # Database drivers
    'dovecot-ldap'         => $auth['type'] == 'ldap',
    'dovecot-mysql'        => $auth['type'] == 'sql' and $auth['driver'] == 'mysql',
    'dovecot-pgsql'        => $auth['type'] == 'sql' and $auth['driver'] == 'pgsql',
    'dovecot-sqlite'       => $auth['type'] == 'sql' and $auth['driver'] == 'sqlite',
  }

  # Unneeded packages are only removed when purge_packages is set, so
  # packages installed by hand or by other modules are left alone.
  if $dovecotng::package_manage {
    $packages.each |String $package, Boolean $needed| {
      if $needed {
        package { $package: ensure => present }
      } elsif $dovecotng::purge_packages {
        package { $package: ensure => absent }
      }
    }
  }
}
