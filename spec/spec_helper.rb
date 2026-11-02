require 'voxpupuli/test/spec_helper'

RSpec.configure do |config|
  config.facterdb_string_keys = false
end

add_mocked_facts!

# A MySQL authentication backend for specs that do not test authentication.
SQL_BACKEND = {
  'type' => 'sql', 'driver' => 'mysql', 'host' => 'localhost', 'database' => 'mail', 'username' => 'dovecot'
}.freeze

# The content of a file whose content is Sensitive, e.g. the files with
# database and LDAP credentials.
def sensitive_content(path)
  resource = catalogue.resource('File', path)
  expect(resource.sensitive_parameters).to include(:content)
  content = resource[:content]
  content.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive) ? content.unwrap : content
end
