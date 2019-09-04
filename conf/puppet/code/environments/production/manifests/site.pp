node 'ca.emojivoto.local' {
  class {'step::certificates':
    version => '0.10.0',
    cli_version => '0.10.1',
  }
}

node 'web.emojivoto.local' {
  class {'step::sds': 
    version => '76b5161',
    cli_version => '0.10.1',
  }
  class {'envoy':
    cluster => 'emojivoto',
    node    => 'web',
    version => 'v1.10.0',
    config  => 'envoy/emojivoto-web.yaml',
  }
  class {'emojivoto':
    version => 'v8',
    image   => 'buoyantio/emojivoto-web',
  }
}

node 'emoji.emojivoto.local' {
  class {'step::sds': 
    version => '76b5161',
    cli_version => '0.10.1',
  }
  class {'envoy': 
    cluster => 'emojivoto',
    node    => 'emoji',
    version => 'v1.10.0',
    config  => 'envoy/emojivoto-emoji.yaml',
  }
  class {'emojivoto':
    version => 'v8',
    image   => 'buoyantio/emojivoto-emoji-svc',
  }
}

node 'voting.emojivoto.local' {
  class {'step::sds': 
    version => '76b5161',
    cli_version => '0.10.1',
  }
  class {'envoy':
    cluster => 'emojivoto',
    node    => 'voting',
    version => 'v1.10.0',
    config  => 'envoy/emojivoto-voting.yaml',
  }
  class {'emojivoto':
    version => 'v8',
    image   => 'buoyantio/emojivoto-voting-svc',
  }
}
