require 'spec_helper'

describe 'dovecotng' do
  let(:facts) do
    {
      os: {
        family: 'Debian',
        name: 'Debian',
        release: { major: '12' },
        distro: { codename: 'bookworm' },
      },
      networking: {
        domain: 'example.test',
        fqdn: 'mail.example.test',
        hostname: 'mail',
        ip: '192.0.2.10',
      },
    }
  end

  let(:params) do
    {
      plugins: [],
      protocols: {},
    }
  end

  it { is_expected.to compile.with_all_deps }

  it 'manages a running and enabled Dovecot service by default' do
    is_expected.to contain_service('dovecot')
      .with_ensure('running')
      .with_enable(true)
      .with_hasstatus(true)
  end

  context 'when service management is disabled' do
    let(:params) { super().merge(service_manage: false) }

    it { is_expected.not_to contain_service('dovecot') }
  end

  context 'when package management is disabled' do
    let(:params) { super().merge(package_manage: false) }

    it { is_expected.not_to contain_package('dovecot-core') }
    it { is_expected.not_to contain_package('dovecot-imapd') }
    it { is_expected.not_to contain_package('dovecot-mysql') }
  end

  context 'when Debian backports are enabled' do
    let(:params) { super().merge(use_backports: true) }

    it 'pins Dovecot packages to the structured-fact backports release' do
      is_expected.to contain_apt__pin('dovecot')
        .with_packages('dovecot*')
        .with_release('bookworm-backports')
        .with_priority(600)
    end
  end
end
