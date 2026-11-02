# Translate the short Dovecot 2.3 variables commonly used in auth queries,
# LDAP filters and mail paths into the Dovecot 2.4 %{...} syntax.
#
# Dovecot 2.4 does not reject the old syntax in config validation, but the
# old variables no longer expand at runtime, so an untranslated SQL query
# silently fails every login.
#
# Translated: %u, %n, %d, %h and their %L (lowercase) / %U (uppercase)
# variants. %% is kept as a literal percent sign, and %{...} variables are
# left untouched, so strings already written for 2.4 pass through unchanged.
#
# Example:
#
#    dovecotng::v24_variables("WHERE localpart = '%n' AND domain = '%Ld'")
#    # => "WHERE localpart = '%{user|username}' AND domain = '%{user|domain|lower}'"
Puppet::Functions.create_function(:'dovecotng::v24_variables') do
  dispatch :translate do
    param 'Optional[String]', :value
    return_type 'Optional[String]'
  end

  def translate(value)
    return value if value.nil?

    variables = { 'u' => 'user', 'n' => 'user|username', 'd' => 'user|domain', 'h' => 'home' }
    modifiers = { '' => '', 'L' => '|lower', 'U' => '|upper' }

    value.gsub(%r{%(%)|%([LU]?)([undh])}) do
      if Regexp.last_match(1)
        '%%'
      else
        "%{#{variables[Regexp.last_match(3)]}#{modifiers[Regexp.last_match(2)]}}"
      end
    end
  end
end
