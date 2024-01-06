class dovecotng::protocol::imap(
   Optional[Integer] $imap_hibernate_timeout = undef,
   Optional[String]  $imap_max_line_length = undef,
   Optional[String]  $imap_logout_format = undef,
   Optional[String]  $imap_capability = undef,
   Optional[String]  $imap_idle_notify_interval = undef,
   Optional[String]  $imap_id_send = undef,
   Optional[String]  $imap_id_log = undef,
   Optional[String]  $imap_client_workarounds = undef,
   Optional[String]  $imap_urlauth_host = undef,
   Optional[String]  $imap_mail_plugins = undef,
   Optional[String]  $imap_literal_minus = undef,
   Optional[String]  $imap_fetch_failure = undef,
   Optional[Integer] $imap_mail_max_userip_connections = undef,
) {

  file { '/etc/dovecot/conf.d/20-imap.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('dovecotng/etc/dovecot/conf.d/20-imap.conf.erb'),
  }
}

