class step::sds(
  $version = false,
  $cli_version = false,
) {
  if !$version {
    fail("class ${name}: version cannot be empty")
  }

  if !$cli_version {
    fail("class ${name}: cli_version cannot be empty")
  }

  # Install cli as a dependency
  class {'step::cli': 
    version =>  $cli_version,
  }

  $pkg = "step-sds_${version}_linux_amd64.tar.gz"
  $download_url = "https://github.com/smallstep/step-sds/releases/download/v${version}/${pkg}"
  $step_sds_exec = '/usr/local/bin/step-sds'

  # template variables
  $ca_url = hiera('pki.ca_url')
  $issuer = hiera('sds.issuer')
  $kid = hiera('sds.kid')
  $description = "Step Secret Discovery Service"
  $exec_start = "${step_sds_exec} run /usr/local/lib/step/config/sds.json --provisioner-password-file /usr/local/lib/step/secrets/provisioner_pass"

  # FIXME: download release file instead of copying tar file
  # exec {
  #   'download/update step-sds':
  #     command => "/usr/bin/curl -s -L -o /tmp/${pkg} ${download_url} && /bin/tar xzvf /tmp/${pkg} -C /tmp && cp /tmp/step-sds_${version}/bin/step-ca ${step_sds_exec}",
  #     unless  => "/usr/bin/which ${step_sds_exec} && ${step_sds_exec} version | grep ${version}",
  #     user    => 'root',
  #     require => File['/usr/local/bin'];
  # }

  file {
    "/tmp/${pkg}":
      source    => "puppet:///modules/step/${pkg}",
      ensure    => file,
      mode      => '0644',
      owner     => 'root';
  }
  exec {
    'install step-sds':
      command => "/bin/tar xzvf /tmp/${pkg} -C /tmp && cp /tmp/step-sds_${version}/bin/step-sds ${step_sds_exec}",
      unless  => "/usr/bin/which ${step_sds_exec} && ${step_sds_exec} version | grep ${version}",
      user    => 'root',
      require => File['/usr/local/bin', "/tmp/${pkg}"];
  }

  file {
    '/usr/local/bin/step-sds':
      ensure  => file,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/certs':
      ensure  => directory,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/secrets':
      ensure  => directory,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/certs/root_ca.crt':
      content => hiera('pki.root_ca_crt'),
      ensure  => present,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/secrets/provisioner_pass':
      content => hiera('sds.password'),
      ensure  => file,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/config':
      ensure  => directory,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/config/sds.json':
      content => template('step/sds.json.erb'),
      ensure  => file,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/lib/systemd/system/step-sds.service':
      content => template('step/service.systemd.erb'),
      mode    => '0644',
      owner   => 'root',
      group   => 'puppet';
  }

  exec { "${name} systemd-reload":
    command     => 'systemctl daemon-reload',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
    refreshonly => true,
  }

  service { 'step-sds':
    ensure   => running,
    enable   => true,
    provider => "systemd",
  }
}
