class dovecotng::protocol::pop3(
  Optional[Boolean] $pop3_no_flag_updates = undef,
  Optional[Boolean] $pop3_enable_last = undef,
  Optional[Boolean] $pop3_reuse_xuidl = undef,
  Optional[Boolean] $pop3_lock_session = undef,
  Optional[Boolean] $pop3_fast_size_lookups = undef,
  Optional[String]  $pop3_uidl_format = undef,
  Optional[Boolean] $pop3_save_uidl = undef,
  Optional[String]  $pop3_uidl_duplicates = undef,
  Optional[String]  $pop3_deleted_flag = undef,
  Optional[String]  $pop3_logout_format = undef,
  Optional[String]  $pop3_client_workarounds = undef,
  Optional[String]  $pop3_mail_plugins = undef,
  Optional[Integer] $pop3_mail_max_userip_connections = undef,
) {

  file { '/etc/dovecot/conf.d/20-pop3.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('dovecotng/etc/dovecot/conf.d/20-pop3.conf.erb'),
  }
}

