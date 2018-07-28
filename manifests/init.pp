class dovecotng(
  Boolean $service_enable  = true,
  Boolean $service_manage  = true,
  String  $service_ensure  = 'running',
  Boolean $package_manage  = true,
  Boolean $use_backports   = false,
  Array   $plugins         = ['antispam'],
  String  $ssl_cert        = undef,
  String  $ssl_key         = undef,
  Boolean $ssl_prefer_server_ciphers = false,
  String  $ssl_additional_config = undef,
  String  $ssl_protocols   = '!SSLv3',
  String  $ssl_cipher_list = 'EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:+CAMELLIA256:+AES256:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!ECDSA:CAMELLIA256-SHA:AES256-SHA:CAMELLIA128-SHA:AES128-SHA',
  String  $vmail_user      = 'vmail',
  String  $vmail_group     = 'vmail',
  String  $vmail_path      = '/srv/mail',
  String  $mail_location   = 'maildir:%h/Maildir',
  Hash    $mail_namespaces = {},
  Hash    $auth_backend    = {
    'type'           => 'sql',
    'driver'         => 'mysql',
    'host'           => 'localhost',
    'database'       => 'smailr',
    'username'       => 'smailr',
    'password'       => 'smailr',
    'password_query' => " \
         SELECT CONCAT(mailboxes.password_scheme, mailboxes.password) AS password, \
                mailboxes.localpart AS username, \
                domains.fqdn AS domain \
           FROM mailboxes, domains \
          WHERE mailboxes.localpart = '%n' \
            AND domains.fqdn = '%d' \
            AND domains.id = mailboxes.domain_id",
    'user_query'     => "",
    'iterate_query'  => "",
  },
  Hash    $services           = {},
  String  $postmaster_address = "postmaster@${::domain}",
  String  $auth_unix_listener_path  = 'auth-client',
  String  $auth_unix_listener_user = 'dovecot',
  String  $auth_unix_listener_group = 'root',
  String  $auth_unix_listener_mode  = '0660',

  Boolean $disable_plaintext_auth   = true,
  Integer $auth_cache_size         = 0,
  Integer $auth_cache_ttl          = 0,
  Integer $auth_cache_negative_ttl = 0,
  Integer $auth_worker_max_count   = 30,
  Integer $auth_failure_delay      = 3,

  Integer $default_process_limit   = 100,
  Integer $default_client_limit    = 1000,

  Integer $anvil_client_limit      = 2000,

  # Logging
  Boolean $auth_verbose           = false,
  Boolean $auth_verbose_passwords = false,
  Boolean $auth_debug             = false,
  Boolean $auth_debug_passwords   = false,
  Boolean $mail_debug             = false,
  Boolean $verbose_ssl            = false,
  Hash    $protocols              = {
      'pop3' => {},
      'imap' => {},
  },
) {

  $ssl_cert_path              = "/etc/ssl/${ssl_cert}.pem"
  $ssl_key_path              = "/etc/ssl/${ssl_cert}.pem"

  $services_defaults = {
    'auth' => {
      'unix_listener' => {
        'auth-userdb' => { 'mode' => '0660', 'user' => $vmail_user, 'group' => $vmail_group },
        'auth-client' => { 'mode' => '0660', 'user' => 'root', 'group' => 'dovecot'  },
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

  contain dovecotng::prepare
  contain dovecotng::install
  contain dovecotng::config

  contain "dovecotng::auth::${auth_backend['type']}"

  contain dovecotng::plugin::antispam
  contain dovecotng::plugin::sieve
  contain dovecotng::service

  Class['dovecotng::prepare']
  -> Class['dovecotng::install']
  -> Class['dovecotng::config']


  $protocols.each |String $proto, $settings| {
    class { "dovecotng::protocol::${proto}":
      * => $settings
    }

    Class['dovecotng::config']
    -> Class["dovecotng::protocol::${proto}"]
  }
}
