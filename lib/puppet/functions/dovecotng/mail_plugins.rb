# Render a mail_plugins setting for the given Dovecot version.
#
# The value uses the Dovecot 2.3 syntax, a space separated plugin list where
# "$mail_plugins" includes the globally configured plugins.
#
# Dovecot 2.4 turned mail_plugins into a boolean list and no longer expands
# "$mail_plugins": a plain assignment replaces the inherited list, and a
# "mail_plugins { plugin = yes }" block adds to it. A value that only
# references "$mail_plugins" renders nothing, as inheriting is the default.
#
# Example:
#
#    dovecotng::mail_plugins('$mail_plugins sieve', '2.4', '  ')
#    # => "  mail_plugins {\n    sieve = yes\n  }"
#    dovecotng::mail_plugins('quota', '2.4', '')
#    # => "mail_plugins = quota"
Puppet::Functions.create_function(:'dovecotng::mail_plugins') do
  dispatch :render do
    param 'Optional[String]', :value
    param 'Enum["2.3", "2.4"]', :version
    optional_param 'String', :indent
    return_type 'Optional[String]'
  end

  def render(value, version, indent = '')
    return nil if value.nil? || value.strip.empty?
    return "#{indent}mail_plugins = #{value.strip}" if version == '2.3'

    plugins = value.split
    inherit = plugins.delete('$mail_plugins')
    return "#{indent}mail_plugins = #{plugins.join(' ')}" unless inherit
    return nil if plugins.empty?

    lines = ["#{indent}mail_plugins {"]
    plugins.each { |plugin| lines << "#{indent}  #{plugin} = yes" }
    lines << "#{indent}}"
    lines.join("\n")
  end
end
