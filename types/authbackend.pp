# The authentication backend configuration of dovecotng::auth_backend.
#
# SQL keys: driver, host (or file for sqlite), database, username, password,
# default_pass_scheme, password_query, user_query and iterate_query.
#
# LDAP keys: uris, binddn, bindpw, base, scope, user_filter, pass_attrs,
# pass_filter, pass_fields (2.4 only), default_pass_scheme and starttls.
type Dovecotng::AuthBackend = Struct[{
  type                          => Enum['sql', 'ldap'],
  Optional[driver]              => Optional[Enum['mysql', 'pgsql', 'sqlite', 'ldap']],
  Optional[host]                => Optional[String[1]],
  Optional[file]                => Optional[String[1]],
  Optional[database]            => Optional[String[1]],
  Optional[username]            => Optional[String[1]],
  Optional[password]            => Optional[Dovecotng::Secret],
  Optional[default_pass_scheme] => Optional[String[1]],
  Optional[password_query]      => Optional[String],
  Optional[user_query]          => Optional[String],
  Optional[iterate_query]       => Optional[String],
  Optional[uris]                => Optional[String[1]],
  Optional[binddn]              => Optional[String[1]],
  Optional[bindpw]              => Optional[Dovecotng::Secret],
  Optional[base]                => Optional[String[1]],
  Optional[scope]               => Optional[Enum['base', 'onelevel', 'subtree']],
  Optional[user_filter]         => Optional[String],
  Optional[pass_attrs]          => Optional[String],
  Optional[pass_filter]         => Optional[String],
  Optional[pass_fields]         => Optional[Hash[String[1], String]],
  Optional[starttls]            => Optional[Boolean],
}]
