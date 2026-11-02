require 'spec_helper'

describe 'dovecotng::check_v24_variables' do
  it { is_expected.to run.with_params('q', nil, '2.4').and_return(nil) }
  it { is_expected.to run.with_params('q', "email = '%{user}'", '2.4').and_return("email = '%{user}'") }
  it { is_expected.to run.with_params('q', "LIKE '100%%'", '2.4').and_return("LIKE '100%%'") }
  it { is_expected.to run.with_params('q', "email = '%Lu'", '2.4').and_raise_error(Puppet::ParseError, %r{q uses Dovecot 2\.3 variables \(%Lu\).*Suggested: email = '%\{user\|lower\}'}) }

  context 'on Dovecot 2.3' do
    it 'warns, returns the value unchanged and marks %u as changeable now' do
      expect(Puppet).to receive(:warning).with(%r{q uses Dovecot 2\.3 variables \(%u\).*can be changed now.*Dovecot 2\.4 form: email = '%\{user\}'})
      is_expected.to run.with_params('q', "email = '%u'", '2.3').and_return("email = '%u'")
    end

    it 'warns to change %n/%d when upgrading' do
      expect(Puppet).to receive(:warning).with(%r{\(%n, %d\).*Change it when upgrading.*'%\{user\|username\}@%\{user\|domain\}'})
      is_expected.to run.with_params('q', "'%n@%d'", '2.3').and_return("'%n@%d'")
    end

    it 'does not warn for portable values' do
      expect(Puppet).not_to receive(:warning)
      is_expected.to run.with_params('q', "email = '%{user}'", '2.3')
    end
  end
end
