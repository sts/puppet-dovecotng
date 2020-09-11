class dovecotng::auth::ldap {
  file {
    default:
        ensure => present,
        owner  => 'root',
        group  => 'root',
        notify => Class['dovecotng::service'];

    '/etc/dovecot/conf.d/auth-ldap.conf.ext':
        content   => template('dovecotng/etc/dovecot/conf.d/auth-ldap.conf.ext.erb');

    '/etc/dovecot/dovecot-ldap.conf.ext':
        mode      => '0640',
        show_diff => false,
        content   => template('dovecotng/etc/dovecot/dovecot-ldap.conf.ext.erb');
  }
}
