Puppet::Parser::Functions.newfunction(:bool2dovecot, type: :rvalue, doc: <<-DOC
 Transform a supposed boolean to yes or no. Pass all other values through.
 Given a nil value (undef), bool2dovecot will return 'no'

 Example:

    $disable_plaintext_auth = true
    $auth_unix_listener_group = 'mail'

    bool2dovecot($disable_plaintext_auth)
    # => 'yes'
    bool2dovecot($auth_unix_listener_group)
    # => 'mail'
    bool2dovecot(undef)
    # => 'no'
DOC
                                     ) do |args|
  raise(Puppet::ParseError, "bool2dovecot() wrong number of arguments. Given: #{args.size} for 1)") if args.size != 1

  arg = args[0]
  return 'no' if arg.nil? || arg == false || arg == :undef
  return 'yes' if arg == true
  return 'no' if arg.is_a?(String) && arg.match?(%r{false}i)
  return 'yes' if arg.is_a?(String) && arg.match?(%r{true}i)

  return arg.to_s
end
