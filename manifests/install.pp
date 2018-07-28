class dovecotng::install
{

  $imapd_state = has_key($::dovecotng::protocols,'imap') ? {
    true  => 'present',
    false => 'absent',
  }

  $pop3d_state = has_key($::dovecotng::protocols,'pop3') ? {
    true  => 'present',
    false => 'absent',
  }

  $managesieve_state = has_key($::dovecotng::protocols,'sieve') ? {
    true  => 'present',
    false => 'absent',
  }

  $antispam_state = member($::dovecotng::plugins,'antispam') ? {
    true  => 'present',
    false => 'absent',
  }

  $sieve_state = member($::dovecotng::plugins,'sieve') ? {
    true  => 'present',
    false => 'absent',
  }

  $mysql_state = "${::dovecotng::auth_backend['type']}/${::dovecotng::auth_backend['driver']}" ? {
    'sql/mysql' => 'present',
    default     => 'absent',
  }

  $sqlite_state = "${::dovecotng::auth_backend['type']}/${::dovecotng::auth_backend['driver']}" ? {
    'sql/sqlite' => 'present',
    default      => 'absent',
  }

  $pgsql_state = "${::dovecotng::auth_backend['type']}/${::dovecotng::auth_backend['driver']}" ? {
    'sql/pgsql' => 'present',
    default     => 'absent',
  }

  $ldap_state = "${::dovecotng::auth_backend['type']}/${::dovecotng::auth_backend['driver']}" ? {
    'ldap/ldap' => 'present',
    default     => 'absent',
  }

  if $::dovecotng::package_manage {
    package {
      'dovecot-core':         ensure => present;

      # Protocols
      'dovecot-imapd':        ensure => $imapd_state;
      'dovecot-pop3d':        ensure => $pop3d_state;
      'dovecot-managesieved': ensure => $managesieve_state;

      # Plugins
      'dovecot-sieve':        ensure => $sieve_state;
      'dovecot-antispam':     ensure => $antispam_state;

      # Database drivers
      'dovecot-ldap':         ensure => $ldap_state;
      'dovecot-mysql':        ensure => $mysql_state;
      'dovecot-pgsql':        ensure => $pgsql_state;
      'dovecot-sqlite':       ensure => $sqlite_state;
    }
  }
}
