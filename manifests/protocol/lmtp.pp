class dovecotng::protocol::lmtp(
  Optional[Boolean] $lmtp_proxy = undef,
  Optional[Boolean] $lmtp_save_to_detail_mailbox = undef,
  Optional[Boolean] $lmtp_rcpt_check_quota = undef,
  Optional[Boolean] $lmtp_add_received_header = undef,
  Optional[Enum['final', 'original', 'none']] $lmtp_hdr_delivery_address = undef,
  Optional[String]  $lmtp_client_workarounds = undef,
  Optional[String]  $lmtp_mail_plugins = undef,
) {

  file { '/etc/dovecot/conf.d/20-lmtp.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('dovecotng/etc/dovecot/conf.d/20-lmtp.conf.erb'),
  }
}
