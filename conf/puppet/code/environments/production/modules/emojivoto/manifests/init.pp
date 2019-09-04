class emojivoto (
  $version = false,
  $image = false,
) {
  if !$version {
    fail("class ${name}: version cannot be empty")
  }

  if !$image {
    fail("class ${name}: image cannot be empty")
  }

  $parts = split($image, '/')
  $command = $parts[1]

  $environment = $command ? {
    'emojivoto-web'        => "WEB_PORT=8080 EMOJISVC_HOST=127.0.0.1:8000 VOTINGSVC_HOST=127.0.0.1:8000 INDEX_BUNDLE=dist/index_bundle.js",
    'emojivoto-emoji-svc'  => "GRPC_PORT=8080",
    'emojivoto-voting-svc' => "GRPC_PORT=8080",
  }

  $extract = $command ? {
    'emojivoto-web' => "#!/bin/sh
                        CONTAINER_ID=$(docker create ${image}:${version})
                        docker cp \$CONTAINER_ID:/usr/local/bin/${command} /usr/local/bin/${command}
                        docker cp \$CONTAINER_ID:/usr/local/bin/dist/index_bundle.js /usr/local/lib/emojivoto/dist/index_bundle.js
                        docker rm \$CONTAINER_ID
                        ",
    default          => "#!/bin/sh
                        CONTAINER_ID=$(docker create ${image}:${version})
                        docker cp \$CONTAINER_ID:/usr/local/bin/${command} /usr/local/bin/${command}
                        docker rm \$CONTAINER_ID
                        ",
  }

  $emojivoto = "#!/bin/sh
  cd /usr/local/lib/emojivoto
  export ${environment}
  exec $@
  "

  # template variables
  $description = "Emojivoto Service (${command})"
  $exec_start = "/usr/local/bin/emojivoto /usr/local/bin/${command}"

  package { 'docker':
    name   => 'docker',
    ensure => installed,
  }

  group { 'emojivoto':
      ensure => present,
      gid    => hiera('gids.emojivoto'),
  }

  user { 'emojivoto':
      ensure     => present,
      gid        => 'puppet',
      home       => '/usr/local/lib/emojivoto',
      managehome => false,
      uid        => hiera('gids.emojivoto'),
  }

  file {
    "/usr/local/bin/${command}":
      ensure  => file,
      mode    => '0755',
      owner   => 'emojivoto',
      group   => 'puppet';
    "/usr/local/bin/emojivoto":
      content => $emojivoto,
      ensure  => file,
      mode    => '0755',
      owner   => 'emojivoto',
      group   => 'puppet';
    '/usr/local/lib/emojivoto':
      ensure  => directory,
      mode    => '0755',
      owner   => 'emojivoto',
      group   => 'puppet';
    '/usr/local/lib/emojivoto/dist':
      ensure  => directory,
      mode    => '0755',
      owner   => 'emojivoto',
      group   => 'puppet';
    '/usr/local/lib/emojivoto/dist/index_bundle.js':
      ensure  => file,
      mode    => '0644',
      owner   => 'emojivoto',
      group   => 'puppet';
    '/usr/local/lib/emojivoto/extract-emojivoto.sh':
      content => $extract,
      ensure  => file,
      mode    => '0755',
      owner   => 'emojivoto',
      group   => 'puppet';
    "/lib/systemd/system/${command}.service":
      content => template('step/service.systemd.erb'),
      mode    => '0644',
      owner   => 'root',
      group   => 'puppet';
  }

  exec { 'extract emojivoto':
    command => "/usr/local/lib/emojivoto/extract-emojivoto.sh",
    require => File['/usr/local/lib/emojivoto/extract-emojivoto.sh'];
  }
  
  exec { "${name} systemd-reload":
    command     => 'systemctl daemon-reload',
    path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
    refreshonly => true,
  }

  service { $command:
    ensure   => running,
    enable   => true,
    provider => "systemd",
  }
}
