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
      package_manage: true,
      service_manage: false,
      ssl_cert: '/etc/ssl/certs/mail.pem',
      ssl_key: '/etc/ssl/private/mail.key',
      plugins: [],
      protocols: {},
      auth_backend: auth_backend,
    }
  end

  context 'with MySQL authentication' do
    let(:auth_backend) do
      {
        'type' => 'sql',
        'driver' => 'mysql',
        'host' => '127.0.0.1',
        'database' => 'mail',
        'username' => 'dovecot',
        'password' => 'secret',
        'default_pass_scheme' => 'SHA512-CRYPT',
        'password_query' => 'SELECT password FROM users WHERE email = \'%u\'',
        'user_query' => '',
        'iterate_query' => '',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'selects only the MySQL Dovecot driver' do
      is_expected.to contain_package('dovecot-mysql').with_ensure('present')
      is_expected.not_to contain_package('dovecot-sqlite')
      is_expected.not_to contain_package('dovecot-pgsql')
      is_expected.not_to contain_package('dovecot-ldap')
    end

    it 'renders the MySQL connection and protects it from Puppet diffs' do
      is_expected.to contain_file('/etc/dovecot/dovecot-sql.conf.ext')
        .with_mode('0640')
        .with_show_diff(false)
      expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext'))
        .to match(%r{^driver = mysql$})
        .and match(%r{^connect = host=127\.0\.0\.1 dbname=mail user=dovecot password=secret$})
        .and match(%r{^default_pass_scheme = SHA512-CRYPT$})
    end
  end

  context 'with SQLite authentication' do
    let(:auth_backend) do
      {
        'type' => 'sql',
        'driver' => 'sqlite',
        'file' => '/var/lib/dovecot/users.sqlite',
        'password_query' => 'SELECT password FROM users WHERE email = \'%u\'',
        'user_query' => '',
        'iterate_query' => '',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'selects the SQLite driver and renders its database path' do
      is_expected.not_to contain_package('dovecot-mysql')
      is_expected.to contain_package('dovecot-sqlite').with_ensure('present')
      expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext'))
        .to match(%r{^driver = sqlite$})
        .and match(%r{^connect = /var/lib/dovecot/users\.sqlite$})
    end
  end
end
