require 'spec_helper'

describe 'dovecotng' do
  def facts_for(major, codename)
    {
      os: { family: 'Debian', name: 'Debian', release: { major: major }, distro: { codename: codename } },
      networking: { domain: 'example.test', fqdn: 'mail.example.test', hostname: 'mail', ip: '192.0.2.10' },
    }
  end

  let(:facts) { facts_for('12', 'bookworm') }
  let(:tls) { { ssl_cert: '/etc/ssl/certs/mail.pem', ssl_key: '/etc/ssl/private/mail.key' } }
  let(:params) { tls.merge(auth_backend: SQL_BACKEND, plugins: [], protocols: {}) }

  describe 'TLS' do
    context 'without a certificate' do
      let(:params) { { auth_backend: SQL_BACKEND, plugins: [], protocols: {} } }

      it { is_expected.to compile.and_raise_error(%r{ssl is 'yes' but ssl_cert or ssl_key is not set}) }
    end

    context 'with ssl disabled and no certificate' do
      let(:params) { { ssl: 'no', auth_backend: SQL_BACKEND, plugins: [], protocols: {} } }

      it 'renders no certificate settings' do
        is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
          .with_content(%r{^ssl = no$})
          .without_content(%r{^ssl_(cert|key) =})
      end
    end

    it 'uses forward-secret AEAD ciphers only by default' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
        .with_content(%r{^ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:})
        .without_content(%r{^ssl_cipher_list = .*(SSLv3|CAMELLIA|AES256-SHA:|AES128-SHA)})
    end
  end

  describe 'service refresh' do
    it 'validates the configuration before reloading Dovecot' do
      is_expected.to contain_exec('dovecotng-validate-config')
        .with_command('doveconf -n > /dev/null')
        .with_refreshonly(true)
      is_expected.to contain_service('dovecot')
        .with_restart('/bin/systemctl reload dovecot')
        .that_subscribes_to('Exec[dovecotng-validate-config]')
    end

    it 'notifies the validation from managed configuration files' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf').that_notifies('Class[dovecotng::service]')
      is_expected.to contain_file('/etc/dovecot/dovecot-sql.conf.ext').that_notifies('Class[dovecotng::service]')
    end

    context 'with service_refresh set to restart' do
      let(:params) { super().merge(service_refresh: 'restart') }

      it { is_expected.to contain_service('dovecot').with_restart(nil) }
    end
  end

  describe 'sieve' do
    it 'manages no sieve directory or compiler when sieve is disabled' do
      is_expected.not_to contain_file('/var/lib/dovecot/sieve.d')
      is_expected.not_to contain_exec('dovecotng-precompile-sieve-before')
      is_expected.to contain_file('/etc/dovecot/conf.d/90-sieve.conf').with_ensure('absent')
    end

    context 'when enabled' do
      let(:params) { super().merge(plugins: ['sieve']) }

      it 'compiles changed scripts after installing the plugin' do
        is_expected.to contain_exec('dovecotng-precompile-sieve-before')
          .with_command('sievec /var/lib/dovecot/sieve.d')
          .with_onlyif(%r{-nt})
          .without_refreshonly
          .that_requires('File[/var/lib/dovecot/sieve.d]')
        is_expected.to contain_class('dovecotng::plugin::sieve').that_requires('Class[dovecotng::config]')
        is_expected.to contain_package('dovecot-sieve').that_comes_before('Exec[dovecotng-precompile-sieve-before]')
      end
    end
  end

  describe 'packages' do
    it 'does not remove packages by default' do
      catalogue.resources.select { |r| r.type == 'Package' }.each do |package|
        expect(package[:ensure]).to eq('present')
      end
      is_expected.not_to contain_package('dovecot-ldap')
    end

    context 'with purge_packages' do
      let(:params) { super().merge(purge_packages: true) }

      it 'removes the packages the configuration does not need' do
        is_expected.to contain_package('dovecot-mysql').with_ensure('present')
        is_expected.to contain_package('dovecot-ldap').with_ensure('absent')
        is_expected.to contain_package('dovecot-sieve').with_ensure('absent')
      end
    end
  end

  describe 'auth_backend' do
    context 'without auth_backend' do
      let(:params) { tls.merge(plugins: [], protocols: {}) }

      it { is_expected.to compile.and_raise_error(%r{auth_backend}) }
    end

    it 'uses the Debian default query and no default connection credentials' do
      expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext'))
        .to match(%r{^connect = host=localhost dbname=mail user=dovecot$})
        .and match(%r{^password_query = SELECT username, domain, password FROM users WHERE username = '%n' AND domain = '%d'$})
    end

    {
      'without a driver' => [{ 'type' => 'sql' }, %r{auth_backend\['driver'\] is required for the sql backend}],
      'MySQL without a host' => [{ 'type' => 'sql', 'driver' => 'mysql', 'database' => 'mail' }, %r{auth_backend\['host'\] is required for the mysql driver}],
      'PostgreSQL without a database' => [{ 'type' => 'sql', 'driver' => 'pgsql', 'host' => 'db' }, %r{auth_backend\['database'\] is required for the pgsql driver}],
      'SQLite without a file' => [{ 'type' => 'sql', 'driver' => 'sqlite' }, %r{auth_backend\['file'\] is required for the sqlite driver}],
    }.each do |name, (backend, error)|
      context name do
        let(:params) { super().merge(auth_backend: backend) }

        it { is_expected.to compile.and_raise_error(error) }
      end
    end

    context 'with an unsupported type' do
      let(:params) { super().merge(auth_backend: { 'type' => 'static' }) }

      it { is_expected.to compile.and_raise_error(%r{auth_backend}) }
    end

    context 'with an unknown key' do
      let(:params) { super().merge(auth_backend: SQL_BACKEND.merge('port' => '3306')) }

      it { is_expected.to compile.and_raise_error(%r{auth_backend}) }
    end

    context 'as a whole Sensitive value' do
      let(:params) { super().merge(auth_backend: sensitive(SQL_BACKEND.merge('password' => 'secret'))) }

      it 'is unwrapped and rendered' do
        expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext')).to match(%r{ password=secret$})
      end
    end

    context 'with a Sensitive password' do
      let(:params) { super().merge(auth_backend: SQL_BACKEND.merge('password' => sensitive('secret'))) }

      it 'is unwrapped and rendered' do
        expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext')).to match(%r{ password=secret$})
      end
    end

    context 'with a Deferred password' do
      let(:params) do
        super().merge(auth_backend: SQL_BACKEND.merge('password' => RSpec::Puppet::RawString.new("Deferred('join', [['s3', 'cret'], ''])")))
      end

      # rspec-puppet resolves Deferred values like the agent does, so this
      # renders the template the way the agent would.
      it 'renders the credentials file from the resolved password' do
        content = catalogue.resource('File', '/etc/dovecot/dovecot-sql.conf.ext')[:content]
        expect(content).to match(%r{^connect = host=localhost dbname=mail user=dovecot password=s3cret$})
      end
    end

    context 'on Dovecot 2.3 without a user_query' do
      it 'uses a static userdb for the vmail user' do
        is_expected.to contain_file('/etc/dovecot/conf.d/auth-sql.conf.ext')
          .with_content(%r{^userdb \{\n  driver = static\n  args = uid=vmail gid=vmail home=/srv/mail/%d/%n\n\}$})
          .without_content(%r{driver = sql\n  args = /etc/dovecot/dovecot-sql\.conf\.ext\n\}\n\z})
        expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext')).not_to match(%r{^(user|iterate)_query})
      end
    end

    context 'on Dovecot 2.3 with a user_query' do
      let(:params) { super().merge(auth_backend: SQL_BACKEND.merge('user_query' => "SELECT home FROM users WHERE email = '%u'")) }

      it 'uses the sql userdb' do
        is_expected.to contain_file('/etc/dovecot/conf.d/auth-sql.conf.ext')
          .with_content(%r{^userdb \{\n  driver = sql\n  args = /etc/dovecot/dovecot-sql\.conf\.ext\n\}$})
          .without_content(%r{driver = static})
        expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext')).to match(%r{^user_query = SELECT home FROM users WHERE email = '%u'$})
      end
    end

    context 'on Dovecot 2.3 with PostgreSQL' do
      let(:params) { super().merge(auth_backend: SQL_BACKEND.merge('driver' => 'pgsql', 'password' => "it's\\x")) }

      it 'quotes the password for libpq' do
        expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext')).to include(%q(password='it\\'s\\\\x'))
      end
    end

    context 'on Dovecot 2.3 with a password containing whitespace' do
      let(:params) { super().merge(auth_backend: SQL_BACKEND.merge('password' => 'se cret')) }

      it { is_expected.to compile.and_raise_error(%r{SQL password must not contain whitespace on Dovecot 2\.3}) }
    end

    context 'on Dovecot 2.3 with SQLite configured through host' do
      let(:params) { super().merge(auth_backend: { 'type' => 'sql', 'driver' => 'sqlite', 'host' => '/var/lib/dovecot/users.sqlite' }) }

      it { expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext')).to match(%r{^connect = /var/lib/dovecot/users\.sqlite$}) }
    end
  end

  describe 'LDAP TLS' do
    let(:ldap) { { 'type' => 'ldap', 'uris' => 'ldap://ldap.example.test', 'base' => 'o=example' } }
    let(:params) { super().merge(auth_backend: ldap) }

    {
      'ldap:// URIs on 2.3' => ['12', 'bookworm', {}, %r{^tls = yes$}],
      'ldaps:// URIs on 2.3' => ['12', 'bookworm', { 'uris' => 'ldaps://ldap.example.test' }, %r{^tls = no$}],
      'StartTLS disabled on 2.3' => ['12', 'bookworm', { 'starttls' => false }, %r{^tls = no$}],
      'ldap:// URIs on 2.4' => ['13', 'trixie', {}, %r{^ldap_starttls = yes$}],
      'StartTLS disabled on 2.4' => ['13', 'trixie', { 'starttls' => false }, %r{^ldap_starttls = no$}],
    }.each do |name, (major, codename, settings, expected)|
      context "with #{name}" do
        let(:facts) { facts_for(major, codename) }
        let(:params) { super().merge(auth_backend: ldap.merge(settings)) }

        it { expect(sensitive_content('/etc/dovecot/dovecot-ldap.conf.ext')).to match(expected) }
        it { is_expected.to contain_package('dovecot-ldap').with_ensure('present') }
      end
    end

    context 'without uris' do
      let(:params) { super().merge(auth_backend: { 'type' => 'ldap' }) }

      it { is_expected.to compile.and_raise_error(%r{auth_backend\['uris'\] is required}) }
    end
  end

  describe 'authentication parameters' do
    let(:params) do
      super().merge(auth_unix_listener_path: 'auth-client', auth_unix_listener_user: 'postfix',
                    auth_unix_listener_group: 'postfix', auth_unix_listener_mode: '0600', auth_failure_delay: 5)
    end

    it 'renders the auth client listener' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-master.conf')
        .with_content(%r{^  unix_listener auth-client \{\n    group = postfix\n    mode = 0600\n    user = postfix\n  \}$})
    end

    it 'renders auth_failure_delay with a unit on 2.3' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-auth.conf').with_content(%r{^auth_failure_delay = 5 secs$})
    end

    context 'on 2.4' do
      let(:facts) { facts_for('13', 'trixie') }

      it { is_expected.to contain_file('/etc/dovecot/conf.d/10-auth.conf').with_content(%r{^auth_failure_delay = 5 secs$}) }
    end
  end

  it 'keeps the previous auth client listener by default' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-master.conf')
      .with_content(%r{^  unix_listener auth-client \{\n    group = dovecot\n    mode = 0660\n    user = root\n  \}$})
  end

  describe 'version detection' do
    context 'with the installed Dovecot 2.4 on Debian 12' do
      let(:facts) { facts_for('12', 'bookworm').merge(dovecot_version: '2.4') }

      it { is_expected.to contain_file('/etc/dovecot/dovecot.conf').with_content(%r{^dovecot_config_version = }) }
    end

    context 'with the installed Dovecot 2.3 on Debian 13' do
      let(:facts) { facts_for('13', 'trixie').merge(dovecot_version: '2.3') }

      it { is_expected.to contain_file('/etc/dovecot/conf.d/10-mail.conf').with_content(%r{^mail_location = }) }
    end

    context 'with an unsupported installed version' do
      let(:facts) { facts_for('13', 'trixie').merge(dovecot_version: '2.2') }

      it { is_expected.to contain_file('/etc/dovecot/dovecot.conf').with_content(%r{^dovecot_config_version = }) }
    end

    context 'with dovecot_version set' do
      let(:facts) { facts_for('13', 'trixie').merge(dovecot_version: '2.4') }
      let(:params) { super().merge(dovecot_version: '2.3') }

      it { is_expected.to contain_file('/etc/dovecot/conf.d/10-mail.conf').with_content(%r{^mail_location = }) }
    end
  end
end
