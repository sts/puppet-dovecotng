require 'voxpupuli/test/spec_helper'

RSpec.configure do |config|
  config.facterdb_string_keys = false
end

add_mocked_facts!
