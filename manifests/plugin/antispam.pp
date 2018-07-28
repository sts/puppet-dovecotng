class dovecotng::plugin::antispam(
  $antispam_mail_sendmail_args = '',
  $antispam_mail_sendmail = '/usr/bin/rspamc',
  $antispam_mail_spam = 'learn_spam',
  $antispam_mail_notspam = 'learn_ham',
) {

  $dovecotng_antispam_state = member($::dovecotng::plugins,'antispam') ? {
    true  => 'present',
    false => 'absent',
  }

  file { '/etc/dovecot/conf.d/90-plugin.antispam.conf':
    ensure  => $dovecotng_antispam_state,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('dovecotng/etc/dovecot/conf.d/90-plugin.antispam.conf.erb'),
    notify  => Class['dovecotng::service']
  }
}
