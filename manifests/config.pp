class dovecotng::config
{
  user { $dovecotng::vmail_user:
    ensure     => present,
    gid        => $dovecotng::vmail_group,
    home       => $dovecotng::vmail_path,
    managehome => false
  }

  group { $dovecotng::vmail_group:
    ensure => present,
  }


  file {
    default:
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      notify => Class['dovecotng::service'];

    '/etc/dovecot':
       ensure  => 'directory';

    '/etc/dovecot/conf.d':
       ensure  => 'directory';

    $dovecotng::vmail_path:
       ensure => directory,
       owner  => $dovecotng::vmail_user,
       group  => $dovecotng::vmail_group,
       mode   => '0750';

    '/etc/dovecot/dovecot.conf':
      content => template('dovecotng/etc/dovecot/dovecot.conf.erb');

    '/etc/dovecot/conf.d/10-auth.conf':
      content => template('dovecotng/etc/dovecot/conf.d/10-auth.conf.erb');

    '/etc/dovecot/conf.d/10-anvil.conf':
      content => template('dovecotng/etc/dovecot/conf.d/10-anvil.conf.erb');

    '/etc/dovecot/conf.d/10-logging.conf':
      content => template('dovecotng/etc/dovecot/conf.d/10-logging.conf.erb');

    '/etc/dovecot/conf.d/10-mail.conf':
      content => template('dovecotng/etc/dovecot/conf.d/10-mail.conf.erb');

    '/etc/dovecot/conf.d/10-master.conf':
      content => template('dovecotng/etc/dovecot/conf.d/10-master.conf.erb');

    '/etc/dovecot/conf.d/10-ssl.conf':
      content => template('dovecotng/etc/dovecot/conf.d/10-ssl.conf.erb');

    '/etc/dovecot/conf.d/15-lda.conf':
      content => template('dovecotng/etc/dovecot/conf.d/15-lda.conf.erb');
  }
}
