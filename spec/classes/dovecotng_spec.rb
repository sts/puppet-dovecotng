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
      service_manage: false,
      auth_backend: SQL_BACKEND,
      ssl_cert: '/etc/ssl/certs/mail.example.test.pem',
      ssl_key: '/etc/ssl/private/mail.example.test.key',
      plugins: ['sieve'],
      protocols: {
        'imap' => { 'imap_mail_max_userip_connections' => 30 },
        'pop3' => {
          'pop3_uidl_format' => '%08Xu%08Xv',
          'pop3_save_uidl' => true,
        },
      },
      mail_namespaces: {
        'inbox' => {
          'separator' => '.',
          'prefix' => 'INBOX.',
        },
      },
      default_process_limit: 2000,
      default_client_limit: 500,
      stats: true,
    }
  end

  it { is_expected.to compile.with_all_deps }

  it 'selects protocol and plugin packages without legacy parser functions' do
    is_expected.to contain_package('dovecot-imapd').with_ensure('present')
    is_expected.to contain_package('dovecot-pop3d').with_ensure('present')
    is_expected.to contain_package('dovecot-sieve').with_ensure('present')
    is_expected.not_to contain_package('dovecot-antispam')
  end

  it 'renders the configured TLS paths and minimum protocol' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
      .with_content(%r{^ssl_cert = </etc/ssl/certs/mail\.example\.test\.pem$})
      .with_content(%r{^ssl_key = </etc/ssl/private/mail\.example\.test\.key$})
      .with_content(%r{^ssl_min_protocol = TLSv1\.2$})
  end

  it 'deep merges mailbox namespace overrides with defaults' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-mail.conf')
      .with_content(%r{^  type = private$})
      .with_content(%r{^  separator = \.$})
      .with_content(%r{^  prefix = INBOX\.$})
      .with_content(%r{^  inbox = yes$})
  end

  it 'renders process limits and the statistics service' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-master.conf')
      .with_content(%r{^default_process_limit = 2000$})
      .with_content(%r{^default_client_limit = 500$})
      .with_content(%r{^service stats \{$})
      .with_content(%r{^  client_limit = 2000$})
  end

  it 'renders protocol-specific IMAP and POP3 settings' do
    is_expected.to contain_file('/etc/dovecot/conf.d/20-imap.conf')
      .with_content(%r{^  mail_max_userip_connections = 30$})
    is_expected.to contain_file('/etc/dovecot/conf.d/20-pop3.conf')
      .with_content(%r{^pop3_uidl_format = %08Xu%08Xv$})
      .with_content(%r{^pop3_save_uidl = yes$})
  end

  it 'derives the default postmaster address from the structured domain fact' do
    is_expected.to contain_file('/etc/dovecot/conf.d/15-lda.conf')
      .with_content(%r{^postmaster_address = postmaster@example\.test$})
  end

  it 'renders false Boolean settings as Dovecot no values' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
      .with_content(%r{^ssl_prefer_server_ciphers = no$})
  end

  it 'renders the default LMTP listener without overrides' do
    is_expected.to contain_file('/etc/dovecot/conf.d/10-master.conf')
      .with_content(%r{^service lmtp \{\n  unix_listener lmtp \{\n  \}$})
  end

  context 'with LMTP listener overrides' do
    let(:params) do
      super().merge(services: { 'lmtp' => { 'unix_listener' => { 'lmtp' => { 'mode' => '0660', 'user' => 'root', 'group' => 'Debian-exim' } } } })
    end

    it 'renders the configured LMTP listener settings' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-master.conf')
        .with_content(%r{^service lmtp \{\n  unix_listener lmtp \{\n    group = Debian-exim\n    mode = 0660\n    user = root\n  \}$})
    end
  end

  it 'does not manage LMTP unless the protocol is enabled' do
    is_expected.not_to contain_package('dovecot-lmtpd')
    is_expected.not_to contain_file('/etc/dovecot/conf.d/20-lmtp.conf')
  end

  context 'with the LMTP protocol enabled' do
    let(:params) do
      super().merge(protocols: super()[:protocols].merge('lmtp' => { 'lmtp_mail_plugins' => '$mail_plugins sieve' }))
    end

    it 'installs the LMTP package and renders the plugin list' do
      is_expected.to contain_package('dovecot-lmtpd').with_ensure('present')
      is_expected.to contain_file('/etc/dovecot/conf.d/20-lmtp.conf')
        .with_content(%r{^protocol lmtp \{\n  # Space separated list of plugins to load \(default is global mail_plugins\)\.\n  mail_plugins = \$mail_plugins sieve\n\}\n\z})
        .without_content(%r{^lmtp_})
    end
  end

  context 'with LMTP settings' do
    let(:params) do
      super().merge(protocols: { 'lmtp' => { 'lmtp_save_to_detail_mailbox' => true, 'lmtp_add_received_header' => false, 'lmtp_hdr_delivery_address' => 'original' } })
    end

    it 'renders the LMTP settings as Dovecot values' do
      is_expected.to contain_file('/etc/dovecot/conf.d/20-lmtp.conf')
        .with_content(%r{^lmtp_save_to_detail_mailbox = yes$})
        .with_content(%r{^lmtp_add_received_header = no$})
        .with_content(%r{^lmtp_hdr_delivery_address = original$})
        .with_content(%r{^  #mail_plugins = \$mail_plugins$})
    end
  end

  context 'with an empty SSL key password' do
    let(:params) { super().merge(ssl_key_password: '') }

    it 'does not render an ssl_key_password setting' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
        .without_content(%r{^ssl_key_password})
    end
  end

  context 'with server cipher preference enabled' do
    let(:params) { super().merge(ssl_prefer_server_ciphers: true) }

    it 'renders true Boolean settings as Dovecot yes values' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-ssl.conf')
        .with_content(%r{^ssl_prefer_server_ciphers = yes$})
    end
  end

  context 'with verbose logging enabled' do
    let(:params) do
      super().merge(
        auth_verbose: true,
        auth_debug: true,
        mail_debug: true,
        verbose_ssl: true,
      )
    end

    it 'renders all enabled logging flags as Dovecot yes values' do
      is_expected.to contain_file('/etc/dovecot/conf.d/10-logging.conf')
        .with_content(%r{^auth_verbose = yes$})
        .with_content(%r{^auth_debug = yes$})
        .with_content(%r{^mail_debug = yes$})
        .with_content(%r{^verbose_ssl = yes$})
    end
  end
end
