class dovecotng::service
{
  # Configuration changes notify this class. The complete configuration is
  # checked with doveconf first; if the check fails, Puppet skips the
  # reload, so the running Dovecot keeps its last working configuration.
  # Only stderr is logged, as the configuration itself may contain secrets.
  exec { 'dovecotng-validate-config':
    command     => 'doveconf -n > /dev/null',
    path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    provider    => 'shell',
    refreshonly => true,
    logoutput   => 'on_failure',
  }

  if $dovecotng::service_manage {
    # A reload applies new settings without dropping client connections;
    # existing sessions finish with the configuration they started with.
    $restart = $dovecotng::service_refresh ? {
      'reload' => '/bin/systemctl reload dovecot',
      default  => undef,
    }

    service { 'dovecot':
      ensure    => $dovecotng::service_ensure,
      enable    => $dovecotng::service_enable,
      hasstatus => true,
      restart   => $restart,
      subscribe => Exec['dovecotng-validate-config'],
    }
  }
}
