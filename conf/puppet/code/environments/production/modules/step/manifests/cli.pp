class step::cli(
  $version = false,
) {
  if !$version {
    fail("class ${name}: version cannot be empty")
  }

  $pkg = "step_${version}_linux_amd64.tar.gz"
  $download_url = "https://github.com/smallstep/cli/releases/download/v${version}/${pkg}"
  $step_exec = '/usr/local/bin/step'

  # template variables
  $ca_url = hiera('pki.ca_url')
  $fingerprint = hiera('pki.fingerprint')

  exec {
    'download/update smallstep':
      command   => "/usr/bin/curl -s -L -o /tmp/${pkg} ${download_url} && /bin/tar -xzvf /tmp/${pkg} -C /tmp && cp /tmp/step_${version}/bin/step ${step_exec}",
      unless    => "/usr/bin/which ${step_exec} && ${step_exec} version | grep ${version}",
      user      => 'root',
      require   => File['/usr/local/bin'];
  }

  file {
    '/usr/local/bin':
      ensure  => directory,
      mode    => '0755',
      owner   => 'root',
      group   => 'root';
    '/usr/local/bin/step':
      ensure  => file,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step':
      ensure  => directory,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/.step':
      ensure  => directory,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/.step/certs':
      ensure  => directory,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/.step/config':
      ensure  => directory,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/.step/certs/root_ca.crt':
      content => hiera('pki.root_ca_crt'),
      ensure  => file,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/.step/config/defaults.json':
      content => template('step/defaults.json.erb'),
      ensure  => file,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
  }

  group { 'step':
      ensure => present,
      gid    => hiera('gids.step'),
  }

  user { 'step':
      ensure     => present,
      gid        => 'puppet',
      home       => '/usr/local/lib/step',
      managehome => false,
      uid        => hiera('gids.step'),
  }
}
