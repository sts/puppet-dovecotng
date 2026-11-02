# Check a value for the short Dovecot 2.3 variables (%u, %n, %d, %h and
# their %L/%U variants) and suggest the Dovecot 2.4 equivalent.
#
# Dovecot 2.4 accepts the old syntax in its config check but no longer
# expands it, so e.g. an SQL query using '%n' silently fails every login.
# The value is never rewritten:
#
# * on Dovecot 2.4 the catalog fails with the suggested rewrite.
# * on Dovecot 2.3 a warning is logged, so the value can be prepared before
#   upgrading. The 2.4 forms %{user|username} and %{user|domain} do not work
#   on 2.3, but %{user} and %{home} work on both versions, so values that only
#   use %u and %h can be changed right away.
#
# Returns the value unchanged.
#
# Example:
#
#    dovecotng::check_v24_variables("auth_backend['password_query']", "email = '%u'", '2.4')
#    # => fails: auth_backend['password_query'] uses Dovecot 2.3 variables (%u) ...
#    #    Suggested: email = '%{user}'
Puppet::Functions.create_function(:'dovecotng::check_v24_variables') do
  dispatch :check do
    param 'String', :setting
    param 'Optional[String]', :value
    param 'Enum["2.3", "2.4"]', :version
    return_type 'Optional[String]'
  end

  def check(setting, value, version)
    return value if value.nil?

    old = value.scan(%r{%%|%[LU]?[undh]}).reject { |v| v == '%%' }.uniq
    return value if old.empty?

    suggestion = call_function('dovecotng::v24_variables', value)

    if version == '2.4'
      raise Puppet::ParseError,
            "dovecotng: #{setting} uses Dovecot 2.3 variables (#{old.join(', ')}), which Dovecot 2.4 " \
            "no longer expands. Rewrite it with %{...} variables. Suggested: #{suggestion}"
    end

    hint = if (old - ['%u', '%h']).empty?
             'This form also works on Dovecot 2.3, so it can be changed now.'
           else
             'Change it when upgrading, as the 2.4 form does not work on Dovecot 2.3.'
           end
    Puppet.warning("dovecotng: #{setting} uses Dovecot 2.3 variables (#{old.join(', ')}), which Dovecot 2.4 " \
                   "no longer expands. #{hint} Dovecot 2.4 form: #{suggestion}")
    value
  end
end
