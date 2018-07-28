class dovecotng::plugin::sieve(
) {

  $sieve_state = member($::dovecotng::plugins,'sieve') ? {
    true  => 'present',
    false => 'absent',
  }

  file {
    default:
      ensure => $sieve_state,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      notify => Class['dovecotng::service'];

    '/etc/dovecot/conf.d/90-sieve.conf':
      content => template('dovecotng/etc/dovecot/conf.d/90-sieve.conf.erb');

    '/var/lib/dovecot/sieve.d':
      ensure  => directory,
      notify  => Exec['dovecotng-precompile-sieve-before'];
  }

  exec { 'dovecotng-precompile-sieve-before':
    command     => '/usr/bin/sievec /var/lib/dovecot/sieve.d',
    user        => 'root',
    refreshonly => true
  }
}
