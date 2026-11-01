class dovecotng::prepare
{
  if $dovecotng::use_backports {
    include apt
    include apt::backports

    $ensure = $dovecotng::use_backports ? {
      true  => present,
      false => absent,
    }

    apt::pin { 'dovecot':
      ensure   => $ensure,
      packages => "dovecot*",
      release  => "${facts['os']['distro']['codename']}-backports",
      priority => 600,
    }
  }
}
