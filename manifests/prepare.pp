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
      release  => "${::lsbdistcodename}-backports",
      priority => 600,
    }
  }
}
