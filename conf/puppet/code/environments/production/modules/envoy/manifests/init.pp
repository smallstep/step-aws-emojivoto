class envoy (
  $cluster = false,
  $node = false,
  $version = false,
  $config = false,
) {
  if !$cluster {
    fail("class ${name}: cluster cannot be empty")
  }

  if !$node {
    fail("class ${name}: node cannot be empty")
  }

  if !$version {
    fail("class ${name}: version cannot be empty")
  }

  if !$config {
    fail("class ${name}: config cannot be empty")
  }

  # template variables
  $exec_start = "/usr/local/bin/envoy -c /usr/local/etc/envoy.yaml --service-cluster ${cluster} --service-node ${node}"

  group { 'envoy':
      ensure => present,
      gid    => hiera('gids.envoy'),
  }

  user { 'envoy':
      ensure     => present,
      gid        => 'puppet',
      home       => '/usr/local/lib/envoy',
      managehome => false,
      uid        => hiera('gids.envoy'),
  }

  package { 'docker.io':
    name   => 'docker.io',
    ensure => installed,
  }

  $extract = "#!/bin/sh
  CONTAINER_ID=$(docker create envoyproxy/envoy:${version})
  docker cp \$CONTAINER_ID:/usr/local/bin/envoy /usr/local/bin/envoy
  docker rm \$CONTAINER_ID
  "

  file {
    '/usr/local/bin/envoy':
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root';
    '/usr/local/lib/envoy':
      ensure  => directory,
      mode    => '0755',
      owner   => 'envoy',
      group   => 'puppet';
    '/usr/local/lib/envoy/extract-envoy.sh':
      content => $extract,
      ensure  => file,
      mode    => '0755',
      owner   => 'envoy',
      group   => 'puppet';
    '/usr/local/etc/envoy.yaml':
      content => file($config),
      ensure  => file,
      mode    => '0755',
      owner   => 'envoy',
      group   => 'puppet';
    '/lib/systemd/system/envoy.service':
      content => template('envoy/envoy.service.erb'),
      mode    => '0644',
      owner   => 'root',
      group   => 'puppet';
  }

  exec { 'extract envoy':
    command => "/usr/local/lib/envoy/extract-envoy.sh",
    require => File['/usr/local/lib/envoy/extract-envoy.sh'];
  }

  exec { "${name} grant net bind access":
    command => '/sbin/setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/envoy',
    require => File['/usr/local/bin/envoy'];
  }

  exec { "${name} systemd-reload":
    command     => 'systemctl daemon-reload',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
    refreshonly => true,
  }

  service { 'envoy':
    ensure   => running,
    enable   => true,
    provider => "systemd",
  }
}
