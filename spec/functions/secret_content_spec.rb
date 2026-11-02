require 'spec_helper'

describe 'dovecotng::secret_content' do
  let(:template) { 'dovecotng/2.4/etc/dovecot/dovecot-sql.conf.ext.epp' }
  let(:connection) do
    { 'driver' => 'mysql', 'host' => 'localhost', 'path' => nil, 'database' => 'mail', 'username' => 'dovecot',
      'default_pass_scheme' => nil, 'queries' => {} }
  end

  it 'renders on the server as Sensitive' do
    result = subject.execute(template, connection.merge('password' => 'se"cret'))
    expect(result).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
    expect(result.unwrap).to include(%(password = "se\\"cret"))
  end

  it 'defers rendering to the agent when a value is Deferred' do
    deferred = Puppet::Pops::Types::TypeFactory.deferred.create('join', [['s3', 'cret'], ''])
    result = subject.execute(template, connection.merge('password' => deferred))
    expect(Puppet::Pops::Types::TypeFactory.deferred.instance?(result)).to be(true)
    expect(result.name).to eq('inline_epp')
    expect(result.arguments[0]).to include('sql_driver = <%= $driver %>')
    expect(result.arguments[1]['password']).to equal(deferred)
  end
end
