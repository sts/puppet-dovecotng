# frozen_string_literal: true

# The major.minor version of the installed Dovecot package, e.g. "2.3".
# Not set when Dovecot is not installed.
Facter.add(:dovecot_version) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('dpkg-query') }

  setcode do
    output = Facter::Core::Execution.execute(
      "dpkg-query -W -f='${db:Status-Status} ${Version}' dovecot-core",
      on_fail: nil,
    )
    status, version = output.to_s.split(' ', 2)
    # Strip the epoch, e.g. "1:2.3.19.1+dfsg1-2.1+deb12u1".
    version.to_s.sub(%r{\A\d+:}, '')[%r{\A\d+\.\d+}] if status == 'installed'
  end
end
