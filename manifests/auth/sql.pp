class dovecotng::auth::sql
{
  $auth = $dovecotng::_auth_backend
  $templates = $dovecotng::template_dir

  # Debian ships no connection defaults, so the connection must be given.
  case $auth['driver'] {
    'mysql', 'pgsql': {
      ['host', 'database'].each |$key| {
        unless $auth[$key] =~ String[1] {
          fail("dovecotng: auth_backend['${key}'] is required for the ${auth['driver']} driver")
        }
      }
    }
    'sqlite': {
      unless $auth['file'] =~ String[1] or $auth['host'] =~ String[1] {
        fail("dovecotng: auth_backend['file'] is required for the sqlite driver")
      }
    }
    default: {
      fail("dovecotng: auth_backend['driver'] is required for the sql backend: mysql, pgsql or sqlite")
    }
  }

  # The queries on a single line; empty queries are left out.
  $queries = Hash(['password_query', 'user_query', 'iterate_query'].map |$key| {
    [$key, $auth[$key] ? {
      String[1] => $auth[$key].regsubst("\n", '', 'G').regsubst(' +', ' ', 'G').strip,
      default   => undef,
    }]
  }.filter |$pair| { $pair[1] =~ String[1] })

  if $dovecotng::version == '2.4' {
    # Dovecot 2.4 no longer expands the short %n/%d/%u variables; fail with
    # a suggested rewrite instead of rendering a query that never matches.
    $queries.each |$key, $query| {
      dovecotng::check_v24_variables("auth_backend['${key}']", $query, '2.4')
    }
  } else {
    # Warn about user supplied queries that need to change before upgrading
    # to 2.4. The module's default query is switched automatically.
    ['password_query', 'user_query', 'iterate_query'].each |$key| {
      dovecotng::check_v24_variables("auth_backend['${key}']", $dovecotng::_auth_input[$key], '2.3')
    }
  }

  # The connection settings, including the password, go to a root-only file
  # rendered from an EPP template; see dovecotng::secret_content.
  $connection = {
    'driver'              => $auth['driver'],
    'host'                => $auth['host'],
    'path'                => $auth['file'] ? { undef => $auth['host'], default => $auth['file'] },
    'database'            => $auth['database'],
    'username'            => $auth['username'],
    'password'            => $auth['password'],
    'default_pass_scheme' => $auth['default_pass_scheme'],
    'queries'             => $queries,
  }

  file {
    default:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      notify => Class['dovecotng::service'];

    '/etc/dovecot/conf.d/auth-sql.conf.ext':
      mode    => '0644',
      content => template("${templates}/conf.d/auth-sql.conf.ext.erb");

    '/etc/dovecot/dovecot-sql.conf.ext':
      mode      => '0640',
      show_diff => false,
      content   => dovecotng::secret_content("${templates}/dovecot-sql.conf.ext.epp", $connection);
  }
}
