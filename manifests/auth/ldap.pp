class dovecotng::auth::ldap {
  $auth = $dovecotng::_auth_backend
  $templates = $dovecotng::template_dir

  unless $auth['uris'] =~ String[1] {
    fail("dovecotng: auth_backend['uris'] is required for the ldap backend")
  }

  # TLS to the LDAP server is on by default: StartTLS for ldap:// URIs,
  # implicit TLS for ldaps:// URIs, where StartTLS must stay off. Set
  # auth_backend['starttls'] to false to disable StartTLS.
  $ldaps_only = $auth['uris'] ? {
    String  => $auth['uris'].split(/[\s,]+/).filter |$uri| { $uri != '' }.all |$uri| { $uri =~ /^ldaps:\/\// },
    default => false,
  }
  $starttls = $auth['starttls'] ? {
    Boolean => $auth['starttls'],
    default => !$ldaps_only,
  }

  if $dovecotng::version == '2.4' {
    $pass_filter = $auth['pass_filter'] ? {
      Undef   => undef,
      ''      => undef,
      default => dovecotng::check_v24_variables("auth_backend['pass_filter']", $auth['pass_filter'], '2.4'),
    }

    # pass_attrs ("ldapAttr=field,...") became a fields block using
    # %{ldap:attr}. Set pass_fields to provide the fields block directly.
    if $auth['pass_fields'] =~ Hash {
      $pass_fields = $auth['pass_fields']
    } elsif $auth['pass_attrs'] =~ String[1] {
      $pass_fields = Hash($auth['pass_attrs'].split(',').map |$attr| {
        $pair = $attr.strip.split('=')
        if $pair.length != 2 {
          fail("dovecotng: cannot translate LDAP pass_attrs entry '${attr}' for Dovecot 2.4, set auth_backend['pass_fields'] instead")
        }
        [$pair[1], "%{ldap:${pair[0]}}"]
      })
    } else {
      $pass_fields = { 'password' => '%{ldap:userPassword}' }
    }
  } else {
    # Warn about variables that need to change before upgrading to 2.4.
    dovecotng::check_v24_variables("auth_backend['pass_filter']", $auth['pass_filter'], '2.3')
  }

  # The connection settings, including the bind password, go to a root-only
  # file rendered from an EPP template; see dovecotng::secret_content.
  $connection = {
    'uris'                => $auth['uris'],
    'binddn'              => $auth['binddn'],
    'bindpw'              => $auth['bindpw'],
    'starttls'            => $starttls,
    'base'                => $auth['base'],
    'scope'               => $auth['scope'],
    'user_filter'         => $auth['user_filter'],
    'pass_attrs'          => $auth['pass_attrs'],
    'pass_filter'         => $auth['pass_filter'],
    'default_pass_scheme' => $auth['default_pass_scheme'],
  }

  file {
    default:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      notify => Class['dovecotng::service'];

    '/etc/dovecot/conf.d/auth-ldap.conf.ext':
      mode    => '0644',
      content => template("${templates}/conf.d/auth-ldap.conf.ext.erb");

    '/etc/dovecot/dovecot-ldap.conf.ext':
      mode      => '0640',
      show_diff => false,
      content   => dovecotng::secret_content("${templates}/dovecot-ldap.conf.ext.epp", $connection);
  }
}
