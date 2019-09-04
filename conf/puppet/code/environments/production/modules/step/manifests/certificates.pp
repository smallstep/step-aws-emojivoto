class step::certificates(
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

  $pkg = "step-certificates_${version}_linux_amd64.tar.gz"
  $download_url = "https://github.com/smallstep/certificates/releases/download/v${version}/${pkg}"
  $step_ca_exec = '/usr/local/bin/step-ca'

  # template variables
  $dns_name = hiera('ca.name')
  $dns_full_name = hiera('ca.dns_name')
  $provisioners_map = hiera('ca.provisioners')
  $provisioners_array = $provisioners_map.map |$k,$v| {"$v"}
  $provisioners = $provisioners_array.join(",")
  $description = "Step Certificates"
  $exec_start = "${$step_ca_exec} /usr/local/lib/step/config/ca.json --password-file /usr/local/lib/step/secrets/intermediate_pass"

  exec {
    'download/update step-ca':
      command => "/usr/bin/curl -s -L -o /tmp/${pkg} ${download_url} && /bin/tar xzvf /tmp/${pkg} -C /tmp && cp /tmp/step-certificates_${version}/bin/step-ca ${step_ca_exec}",
      unless  => "/usr/bin/which ${step_ca_exec} && ${step_ca_exec} version | grep ${version}",
      user    => 'root',
      require => File['/usr/local/bin'];
  }

  file {
    '/usr/local/bin/step-ca':
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
    '/usr/local/lib/step/certs/intermediate_ca.crt':
      content => hiera('pki.intermediate_ca_crt'),
      ensure  => file,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/secrets/intermediate_ca_key':
      content => hiera('pki.intermediate_ca_key'),
      ensure  => file,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/secrets/intermediate_pass':
      content => hiera('pki.password'),
      ensure  => file,
      mode    => '0644',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/config':
      ensure  => directory,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/usr/local/lib/step/config/ca.json':
      content => template('step/ca.json.erb'),
      ensure  => file,
      mode    => '0755',
      owner   => 'step',
      group   => 'puppet';
    '/lib/systemd/system/step-ca.service':
      content => template('step/service.systemd.erb'),
      mode    => '0644',
      owner   => 'root',
      group   => 'puppet';
  }

  exec { "${name} grant net bind access":
    command => '/sbin/setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/step-ca',
    require => File['/usr/local/bin/step-ca'];
  }

  exec { "${name} systemd-reload":
    command     => 'systemctl daemon-reload',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
    refreshonly => true,
  }

  service { 'step-ca':
    ensure   => running,
    enable   => true,
    provider => "systemd",
  }
}
