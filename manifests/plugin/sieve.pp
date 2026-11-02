class dovecotng::plugin::sieve(
) {

  $enabled = 'sieve' in $dovecotng::_plugins

  file { '/etc/dovecot/conf.d/90-sieve.conf':
    ensure  => $enabled ? { true => 'file', default => 'absent' },
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${dovecotng::template_dir}/conf.d/90-sieve.conf.erb"),
    notify  => Class['dovecotng::service'],
  }

  if $enabled {
    file { '/var/lib/dovecot/sieve.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Compile the global sieve_before scripts whenever a script is newer
    # than its compiled binary, no matter who manages the scripts.
    exec { 'dovecotng-precompile-sieve-before':
      command  => 'sievec /var/lib/dovecot/sieve.d',
      onlyif   => 'for f in /var/lib/dovecot/sieve.d/*.sieve; do [ -e "$f" ] || continue; b="${f%.sieve}.svbin"; if [ ! -e "$b" ] || [ "$f" -nt "$b" ]; then exit 0; fi; done; exit 1',
      path     => ['/usr/bin', '/bin'],
      provider => 'shell',
      user     => 'root',
      require  => File['/var/lib/dovecot/sieve.d'],
    }
  }
}
