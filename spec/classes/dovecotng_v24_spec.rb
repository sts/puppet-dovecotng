require 'spec_helper'

describe 'dovecotng' do
  let(:facts) do
    {
      os: {
        family: 'Debian',
        name: 'Debian',
        release: { major: '13' },
        distro: { codename: 'trixie' },
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
      service_manage: false,
      auth_backend: SQL_BACKEND,
      ssl_cert: '/etc/ssl/certs/mail.pem',
      ssl_key: '/etc/ssl/private/mail.key',
    }
  end

  it { is_expected.to compile.with_all_deps }

  it 'selects Dovecot 2.4 on Debian 13 and does not default to the antispam plugin' do
    is_expected.to contain_file('/etc/dovecot/dovecot.conf')
      .with_content(%r{\A# This file is managed by Puppet\.\n#.*\n#.*\n#.*\n#.*\ndovecot_config_version = 2\.4\.0\ndovecot_storage_version = 2\.4\.0\n}m)
    is_expected.not_to contain_package('dovecot-antispam')
    is_expected.to contain_file('/etc/dovecot/conf.d/90-plugin.antispam.conf').with_ensure('absent')
  end

  it 'translates mail_location to mail_driver and mail_path' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-mail.conf')
      .with_content(%r{^mail_driver = maildir$})
      .with_content(%r{^mail_path = %\{home\}/Maildir$})
      .without_content(%r{mail_location})
  end

  it 'renders the 2.4 authentication and SSL setting names' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-auth.conf')
      .with_content(%r{^auth_allow_cleartext = no$})
      .with_content(%r{^service auth-worker \{\n  process_limit = 30\n\}$})
    is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
      .with_content(%r{^ssl_server_cert_file = /etc/ssl/certs/mail\.pem$})
      .with_content(%r{^ssl_server_key_file = /etc/ssl/private/mail\.key$})
      .with_content(%r{^ssl_server_prefer_ciphers = client$})
  end

  it 'references settings with the 2.4 $SET: syntax' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-master.conf')
      .with_content(%r{^  user = \$SET:default_internal_user$})
      .without_content(%r{= \$default_internal_user})
  end

  it 'renders SQL passdb/userdb blocks with the 2.4 default query' do
    is_expected.to contain_file('/etc/dovecot/conf.d/auth-sql.conf.ext')
      .with_mode('0644')
      .with_content(%r{^!include_try /etc/dovecot/dovecot-sql\.conf\.ext$})
      .with_content(%r{^passdb sql \{\n  query = SELECT username, domain, password FROM users WHERE username = '%\{user\|username\}' AND domain = '%\{user\|domain\}'\n\}$})
      .with_content(%r{^userdb static \{\n  fields \{\n    uid = vmail\n    gid = vmail\n    home = /srv/mail/%\{user\|domain\}/%\{user\|username\}\n})
  end

  it 'keeps the SQL credentials in a root-only file' do
    is_expected.to contain_file('/etc/dovecot/dovecot-sql.conf.ext')
      .with_mode('0640')
      .with_show_diff(false)
    expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext'))
      .to match(%r{^sql_driver = mysql$})
      .and match(%r{^mysql localhost \{\n  dbname = mail\n  user = dovecot\n\}$})
  end

  it 'renders the Pigeonhole 2.4 sieve settings' do
    is_expected.to contain_file('/etc/dovecot/conf.d/90-sieve.conf').with_ensure('absent')
  end

  context 'with sieve, LMTP and verbose SSL' do
    let(:params) do
      super().merge(
        plugins: ['sieve'],
        verbose_ssl: true,
        protocols: {
          'imap' => { 'imap_id_send' => { 'name' => 'Dovecot' }, 'imap_mail_plugins' => '$mail_plugins imap_sieve' },
          'lmtp' => { 'lmtp_mail_plugins' => '$mail_plugins sieve' },
        },
      )
    end

    it { is_expected.to compile.with_all_deps }

    it 'renders sieve_script blocks and the renamed spamtest header' do
      is_expected.to contain_file('/etc/dovecot/conf.d/90-sieve.conf')
        .with_ensure('file')
        .with_content(%r{^sieve_script personal \{\n  driver = file\n  path = ~/sieve\n  active_path = ~/\.dovecot\.sieve\n\}$})
        .with_content(%r{^sieve_script before \{\n  type = before\n})
        .with_content(%r{^sieve_spamtest_score_max_header = })
        .without_content(%r{^\s*(notify|imapflags) = })
    end

    it 'renders mail_plugins as boolean lists' do
      is_expected.to contain_file('/etc/dovecot/conf.d/20-lmtp.conf')
        .with_content(%r{^protocol lmtp \{\n(  #.*\n)*  mail_plugins \{\n    sieve = yes\n  \}\n\}$})
      is_expected.to contain_file('/etc/dovecot/conf.d/20-imap.conf')
        .with_content(%r{^imap_id_send \{\n  name = Dovecot\n\}$})
        .with_content(%r{^  mail_plugins \{\n    imap_sieve = yes\n  \}$})
    end

    it 'maps verbose_ssl to a log_debug filter' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-logging.conf')
        .with_content(%r{^log_debug = category=ssl$})
        .without_content(%r{^verbose_ssl})
    end
  end

  context 'with SQLite and a user query' do
    let(:params) do
      super().merge(auth_backend: {
                      'type' => 'sql',
                      'driver' => 'sqlite',
                      'file' => '/var/lib/dovecot/users.sqlite',
                      'password_query' => "SELECT password FROM users WHERE email = '%{user}'",
                      'user_query' => "SELECT home FROM users WHERE email = '%{user}'",
                      'iterate_query' => 'SELECT email AS user FROM users',
                    })
    end

    it 'renders sqlite_path and a sql userdb' do
      is_expected.to contain_package('dovecot-sqlite').with_ensure('present')
      expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext'))
        .to match(%r{^sql_driver = sqlite\nsqlite_path = /var/lib/dovecot/users\.sqlite$})
      is_expected.to contain_file('/etc/dovecot/conf.d/auth-sql.conf.ext')
        .with_content(%r{^userdb sql \{\n  query = SELECT home FROM users WHERE email = '%\{user\}'\n  iterate_query = SELECT email AS user FROM users\n\}$})
        .without_content(%r{userdb static})
    end
  end

  context 'with PostgreSQL authentication' do
    let(:params) do
      super().merge(auth_backend: {
                      'type' => 'sql', 'driver' => 'pgsql', 'host' => 'db.example.test', 'database' => 'mail',
                      'username' => 'dovecot', 'password' => 'se"cret',
                      'password_query' => "SELECT password FROM users WHERE email = '%{user}'"
                    })
    end

    it 'renders pgsql connection parameters with a quoted password' do
      expect(sensitive_content('/etc/dovecot/dovecot-sql.conf.ext'))
        .to match(%r{^pgsql db\.example\.test \{\n  parameters \{\n    dbname = mail\n    user = dovecot\n    password = "se\\"cret"\n  \}\n\}$})
    end
  end

  context 'with LDAP authentication' do
    let(:params) do
      super().merge(auth_backend: {
                      'type' => 'ldap', 'driver' => 'ldap', 'uris' => 'ldaps://ldap1.example.com',
                      'binddn' => 'cn=manager,o=example', 'bindpw' => 'S3cr3t', 'base' => 'ou=mbox,o=example',
                      'scope' => 'subtree', 'pass_attrs' => 'mail=user,userPassword=password',
                      'pass_filter' => '(&(mail=%{user})(objectClass=qmailUser))'
                    })
    end

    it { is_expected.to compile.with_all_deps }

    it 'renders the LDAP passdb filter and fields' do
      is_expected.to contain_file('/etc/dovecot/conf.d/auth-ldap.conf.ext')
        .with_content(%r{^  ldap_filter = \(&\(mail=%\{user\}\)\(objectClass=qmailUser\)\)$})
        .with_content(%r{^  fields \{\n    password = %\{ldap:userPassword\}\n    user = %\{ldap:mail\}\n  \}$})
      is_expected.to contain_file('/etc/dovecot/dovecot-ldap.conf.ext').with_mode('0640')
      expect(sensitive_content('/etc/dovecot/dovecot-ldap.conf.ext'))
        .to match(%r{^ldap_uris = ldaps://ldap1\.example\.com$})
        .and match(%r{^ldap_auth_dn_password = "S3cr3t"$})
        .and match(%r{^ldap_starttls = no$})
    end
  end

  context 'with a SQL query using Dovecot 2.3 variables' do
    let(:params) do
      super().merge(auth_backend: {
                      'type' => 'sql', 'driver' => 'mysql', 'host' => 'localhost', 'database' => 'mail',
                      'username' => 'dovecot', 'password' => 'secret',
                      'password_query' => "SELECT password FROM users WHERE localpart = '%n' AND domain = '%d'"
                    })
    end

    it 'fails and suggests the 2.4 query instead of rewriting it' do
      is_expected.to compile.and_raise_error(
        %r{auth_backend\['password_query'\] uses Dovecot 2\.3 variables \(%n, %d\).*Suggested: SELECT password FROM users WHERE localpart = '%\{user\|username\}' AND domain = '%\{user\|domain\}'},
      )
    end
  end

  context 'with an LDAP filter using Dovecot 2.3 variables' do
    let(:params) do
      super().merge(auth_backend: {
                      'type' => 'ldap', 'driver' => 'ldap', 'uris' => 'ldap://ldap1.example.com',
                      'binddn' => 'cn=manager', 'bindpw' => 'secret', 'base' => 'o=example',
                      'pass_filter' => '(mail=%u)'
                    })
    end

    it { is_expected.to compile.and_raise_error(%r{auth_backend\['pass_filter'\] uses Dovecot 2\.3 variables \(%u\).*Suggested: \(mail=%\{user\}\)}) }
  end

  context 'with the antispam plugin' do
    let(:params) { super().merge(plugins: ['antispam']) }

    it { is_expected.to compile.and_raise_error(%r{antispam plugin is not available for Dovecot 2\.4}) }
  end

  context 'with a mail_location that cannot be translated' do
    let(:params) { super().merge(mail_location: 'maildir:~/Maildir:INBOX=/var/mail/%u') }

    it { is_expected.to compile.and_raise_error(%r{set mail_driver and mail_path instead}) }
  end

  context 'with explicit mail_driver and mail_path' do
    let(:params) { super().merge(mail_driver: 'sdbox', mail_path: '~/sdbox', mail_home: '/srv/mail/%d/%n') }

    it 'uses them as given' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-mail.conf')
        .with_content(%r{^mail_driver = sdbox\nmail_path = ~/sdbox\nmail_home = /srv/mail/%\{user\|domain\}/%\{user\|username\}$})
    end
  end

  context 'when Dovecot 2.3 is forced on Debian 13' do
    let(:params) { super().merge(dovecot_version: '2.3') }

    it 'renders the 2.3 configuration' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-mail.conf').with_content(%r{^mail_location = maildir:%h/Maildir$})
      is_expected.to contain_package('dovecot-antispam').with_ensure('present')
    end

    it 'does not warn about the default query' do
      expect(Puppet).not_to receive(:warning).with(%r{dovecotng})
      is_expected.to compile
    end
  end
end
