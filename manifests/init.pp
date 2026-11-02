class dovecotng(
  Optional[Enum['2.3', '2.4']] $dovecot_version = undef,
  String  $dovecot_config_version  = '2.4.0',
  String  $dovecot_storage_version = '2.4.0',
  Boolean $service_enable   = true,
  Boolean $service_manage   = true,
  String  $service_ensure   = 'running',
  Enum['reload', 'restart'] $service_refresh = 'reload',
  Boolean $package_manage   = true,
  Boolean $purge_packages   = false,
  Boolean $use_backports    = false,
  Optional[Array[String]] $plugins = undef,
  Enum['yes', 'no', 'required'] $ssl = 'yes',
  Optional[String] $ssl_cert         = undef,
  Optional[String] $ssl_key          = undef,
  Optional[String] $ssl_key_password = undef,
  Boolean $ssl_prefer_server_ciphers = false,
  Optional[String] $ssl_additional_config = undef,
  Optional[String] $ssl_dh_params = undef,
  String  $ssl_min_protocol = 'TLSv1.2',
  # Mozilla "intermediate" profile: forward secrecy and AEAD ciphers only.
  String  $ssl_cipher_list  = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305',
  String  $vmail_user       = 'vmail',
  String  $vmail_group      = 'vmail',
  String  $vmail_path       = '/srv/mail',
  String  $mail_location    = 'maildir:%h/Maildir',
  Optional[String] $mail_driver = undef,
  Optional[String] $mail_path   = undef,
  Optional[String] $mail_home   = undef,
  Hash    $mail_namespaces  = {},
  # Required: Debian ships no SQL or LDAP connection defaults.
  Variant[Dovecotng::AuthBackend, Sensitive[Dovecotng::AuthBackend]] $auth_backend,
  Hash    $services           = {},
  String  $postmaster_address = "postmaster@${facts['networking']['domain']}",
  String  $auth_unix_listener_path  = 'auth-client',
  String  $auth_unix_listener_user = 'root',
  String  $auth_unix_listener_group = 'dovecot',
  String  $auth_unix_listener_mode  = '0660',

  Boolean $disable_plaintext_auth   = true,
  Integer $auth_cache_size         = 0,
  String  $auth_cache_ttl          = '0',
  String  $auth_cache_negative_ttl = '0',
  Integer $auth_worker_max_count   = 30,
  Integer[0] $auth_failure_delay   = 2,

  Integer $default_process_limit   = 100,
  Integer $default_client_limit    = 1000,

  Integer $anvil_client_limit      = 2000,

  # Logging
  String  $log_debug              = "",
  String  $log_core_filter        = "",
  Boolean $auth_verbose           = false,
  Boolean $auth_verbose_passwords = false,
  Boolean $auth_debug             = false,
  Boolean $auth_debug_passwords   = false,
  Boolean $mail_debug             = false,
  Boolean $stats                  = false,
  Boolean $verbose_ssl            = false,
  Hash    $lda                    = {},
  Hash    $protocols              = {
      'pop3' => {},
      'imap' => {},
  },
) {

  # The Dovecot version to configure: the dovecot_version parameter, else
  # the installed package (dovecot_version fact), else the version Debian
  # ships: Debian 13 (trixie) ships Dovecot 2.4, earlier releases ship 2.3.
  $version = $dovecot_version ? {
    undef   => $facts['dovecot_version'] ? {
      Enum['2.3', '2.4'] => $facts['dovecot_version'],
      default            => versioncmp($facts['os']['release']['major'], '13') ? {
        -1      => '2.3',
        default => '2.4',
      },
    },
    default => $dovecot_version,
  }

  # Templates that differ between Dovecot 2.3 and 2.4.
  $template_dir = $version ? {
    '2.4'   => 'dovecotng/2.4/etc/dovecot',
    default => 'dovecotng/etc/dovecot',
  }

  if $ssl != 'no' and ($ssl_cert =~ Undef or $ssl_key =~ Undef) {
    fail("dovecotng: ssl is '${ssl}' but ssl_cert or ssl_key is not set; Dovecot cannot serve TLS without them. Set both, or set ssl to 'no'")
  }

  # dovecot-antispam does not exist for Dovecot 2.4; use IMAPSieve instead.
  $_plugins = $plugins ? {
    undef   => $version ? {
      '2.4'   => [],
      default => ['antispam'],
    },
    default => $plugins,
  }

  if $version == '2.4' and 'antispam' in $_plugins {
    fail('dovecotng: the antispam plugin is not available for Dovecot 2.4, remove it from $plugins')
  }

  if $version == '2.4' {
    # mail_location was split into mail_driver, mail_path and friends.
    # Derive them from a simple "driver:path" mail_location, which keeps the
    # common configurations working without changes.
    if $mail_driver =~ NotUndef {
      $_mail_driver = $mail_driver
      $_mail_path   = $mail_path
    } else {
      $_mail_location_parts = $mail_location.split(':')
      if $_mail_location_parts.length != 2 {
        fail("dovecotng: cannot translate mail_location '${mail_location}' for Dovecot 2.4, set mail_driver and mail_path instead")
      }
      $_mail_driver = $_mail_location_parts[0]
      $_mail_path   = pick($mail_path, dovecotng::v24_variables($_mail_location_parts[1]))
    }

    $mail_namespaces.each |$name, $settings| {
      if $settings['location'] =~ String[1] {
        fail("dovecotng: namespace '${name}' uses location, which Dovecot 2.4 replaced with mail_driver and mail_path")
      }
    }
  }

  # The default password query: Dovecot 2.3's built-in default, as
  # documented in Debian's dovecot-sql.conf.ext, in the variable syntax of
  # the selected Dovecot version. Both use the same users table.
  $default_password_query = $version ? {
    '2.4'   => "SELECT username, domain, password FROM users WHERE username = '%{user|username}' AND domain = '%{user|domain}'",
    default => "SELECT username, domain, password FROM users WHERE username = '%n' AND domain = '%d'",
  }

  # auth_backend can be passed as a whole as Sensitive, for example with a
  # Hiera lookup_options convert_to.
  $_auth_input = ($auth_backend =~ Sensitive ? {
    true    => $auth_backend.unwrap,
    default => $auth_backend,
  }).filter |$key, $value| { $value =~ NotUndef }

  $auth_defaults = $_auth_input['type'] ? {
    'sql'   => {
      'password_query' => $default_password_query,
    },
    default => {
      'driver' => 'ldap',
    },
  }

  $_auth_backend = $auth_defaults + $_auth_input

  $services_defaults = {
    'auth' => {
      'unix_listener' => {
        'auth-userdb' => { 'mode' => '0660', 'user' => $vmail_user, 'group' => $vmail_group },
        $auth_unix_listener_path => {
          'mode'  => $auth_unix_listener_mode,
          'user'  => $auth_unix_listener_user,
          'group' => $auth_unix_listener_group,
        },
      },
    },
    'lmtp' => {
      'unix_listener' => {
        'lmtp' => {},
      },
    },
  }

  $_services = deep_merge($services_defaults, $services)

  $mail_namespaces_defaults = {
    'inbox' => {
      'type' => 'private',
      'separator' => '',
      'prefix' => '',
      'inbox' => 'yes',
      'hidden' => 'no',
      'list' => 'yes',
      'subscriptions' => 'yes',
    }
  }

  $_mail_namespaces = deep_merge($mail_namespaces_defaults, $mail_namespaces)


  $lda_defaults = {
    'quota_full_tempfail'           => false,
    'recipient_delimiter'           => '+',
    'lda_mailbox_autocreate'        => true,
    'lda_mailbox_autosubscribe'     => true,
    'lda_original_recipient_header' => '',
  }

  $_lda = deep_merge($lda_defaults, $lda)

  contain dovecotng::prepare
  contain dovecotng::install
  contain dovecotng::config

  contain "dovecotng::auth::${_auth_backend['type']}"

  contain dovecotng::plugin::antispam
  contain dovecotng::plugin::sieve
  contain dovecotng::service

  Class['dovecotng::prepare']
  -> Class['dovecotng::install']
  -> Class['dovecotng::config']
  -> [Class["dovecotng::auth::${_auth_backend['type']}"], Class['dovecotng::plugin::antispam'], Class['dovecotng::plugin::sieve']]


  $protocols.each |String $proto, $settings| {
    class { "dovecotng::protocol::${proto}":
      * => $settings
    }

    Class['dovecotng::config']
    -> Class["dovecotng::protocol::${proto}"]
  }
}
