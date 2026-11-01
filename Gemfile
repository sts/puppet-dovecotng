source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  gem 'puppet_metadata', '~> 6.4', require: false
  gem 'voxpupuli-test', '~> 15.0', require: false
end

gem 'openvox', ENV.fetch('OPENVOX_GEM_VERSION', ['>= 8', '< 9']), require: false, groups: [:test]
gem 'rake', '~> 13.0', require: false
