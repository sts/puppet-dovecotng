class dovecotng::auth::sql
{
  # TODO move to params file
  if $dovecotng::auth_backend['driver'] == 'sqlite' {
    $connect = "${dovecotng::auth_backend['file']}"
  } else {
    $connect = "host=${dovecotng::auth_backend['host']} dbname=${dovecotng::auth_backend['database']} user=${dovecotng::auth_backend['username']} password=${dovecotng::auth_backend['password']}"
  }

  file {
    default:
      ensure => present,
      owner  => 'root',
      group  => 'root',
      notify => Class['dovecotng::service'];

    '/etc/dovecot/conf.d/auth-sql.conf.ext':
      content   => template('dovecotng/etc/dovecot/conf.d/auth-sql.conf.ext.erb');

    '/etc/dovecot/dovecot-sql.conf.ext':
      mode      => '0640',
      show_diff => false,
      content   => template('dovecotng/etc/dovecot/dovecot-sql.conf.ext.erb');
  }
}
