class dovecotng::service
{
  if $::dovecotng::service_manage {
    service { 'dovecot':
      ensure    => $::dovecotng::service_ensure,
      enable    => $::dovecotng::service_enable,
      hasstatus => true,
    }
  }
}
