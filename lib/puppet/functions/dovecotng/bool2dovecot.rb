# Transform a supposed boolean to yes or no. Pass all other values through.
# Given a nil value (undef), bool2dovecot will return 'no'. Only the exact
# strings "true" and "false" (any case) are treated as booleans, so values
# like "falsepositives/" pass through unchanged.
#
# Example:
#
#    $disable_plaintext_auth = true
#    $auth_unix_listener_group = 'mail'
#
#    bool2dovecot($disable_plaintext_auth)
#    # => 'yes'
#    bool2dovecot($auth_unix_listener_group)
#    # => 'mail'
#    bool2dovecot(undef)
#    # => 'no'
Puppet::Functions.create_function(:'dovecotng::bool2dovecot') do
  def bool2dovecot(arg)
    return 'no' if arg.nil? || arg == false || arg == :undef
    return 'yes' if arg == true
    return 'no' if arg.is_a?(String) && arg.match?(%r{\Afalse\z}i)
    return 'yes' if arg.is_a?(String) && arg.match?(%r{\Atrue\z}i)

    arg.to_s
  end
end
