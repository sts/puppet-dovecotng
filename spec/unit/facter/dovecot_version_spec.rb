require 'spec_helper'

describe 'dovecot_version' do
  before(:each) do
    Facter.clear
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
    allow(Facter::Core::Execution).to receive(:which).and_call_original
    allow(Facter::Core::Execution).to receive(:which).with('dpkg-query').and_return('/usr/bin/dpkg-query')
  end

  after(:each) { Facter.clear }

  def dpkg_returns(output)
    allow(Facter::Core::Execution).to receive(:execute)
      .with(%r{dpkg-query -W .* dovecot-core}, on_fail: nil).and_return(output)
  end

  it 'reports major.minor of the installed package without the epoch' do
    dpkg_returns('installed 1:2.3.19.1+dfsg1-2.1+deb12u1')
    expect(Facter.fact(:dovecot_version).value).to eq('2.3')
  end

  it 'reports Dovecot 2.4' do
    dpkg_returns('installed 1:2.4.1+dfsg1-6')
    expect(Facter.fact(:dovecot_version).value).to eq('2.4')
  end

  it 'is not set when the package is only configured or removed' do
    dpkg_returns('config-files 1:2.3.19.1+dfsg1-2.1+deb12u1')
    expect(Facter.fact(:dovecot_version).value).to be_nil
  end

  it 'is not set when the package is unknown' do
    dpkg_returns(nil)
    expect(Facter.fact(:dovecot_version).value).to be_nil
  end
end
