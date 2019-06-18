#
#
#
class medialibrary::oaipmh_docker(
  $ml_db_url,
  $ml_db_db,
  $ml_db_user,
  $ml_db_pwd,
  $media_server_url,
  $listen_port      = '8080',
  $logfile_location = '/var/log/oai-pmh.log',
  $sets             = 'hiera_based',
){


  Ini_setting {
      ensure            => present,
      path              => '/opt/oai-pmh/extract/WEB-INF/classes/config.properties',
      section           => '',
      key_val_separator => '=',
      require           => Exec['/bin/rm -fr /opt/oai-pmh/extract/WEB-INF/classes/config.properties'],
      notify            => Service['docker-medialibrary-oai-pmh'],
  }

  include 'docker'

  package {'unzip':}

  file {['/opt/oai-pmh','/opt/oai-pmh/extract','/var/log/docker-medialibrary-oai-pmh']:
    ensure => 'directory',
  }

  file {'/opt/oai-pmh/oai-pmh.war':
    ensure  => present,
    source  => 'puppet:///modules/medialibrary/oai-pmh.war',
    require => File['/opt/oai-pmh/extract'],
    notify  => Exec['/usr/bin/unzip /opt/oai-pmh/oai-pmh.war -d /opt/oai-pmh/extract'],
  }

  exec {'/usr/bin/unzip /opt/oai-pmh/oai-pmh.war -d /opt/oai-pmh/extract':
    refreshonly => true,
    notify      => Exec['/bin/rm -fr /opt/oai-pmh/extract/WEB-INF/classes/config.properties'],
  }

  file {'/opt/oai-pmh/extract/WEB-INF/classes/logback.xml':
    ensure  => absent,
    content => template('medialibrary/logback.xml.erb'),
    mode    => '0660',
    require => Exec['/usr/bin/unzip /opt/oai-pmh/oai-pmh.war -d /opt/oai-pmh/extract'],
    notify  => Service['docker-medialibrary-oai-pmh']
  }

  exec {'/bin/rm -fr /opt/oai-pmh/extract/WEB-INF/classes/config.properties' :
    refreshonly => true,
  }

  ini_setting { 'ini_db_dsn':
    setting => 'db_dsn',
    value   => "jdbc\:mysql\://${ml_db_url}/${ml_db_db}",
  }

  ini_setting { 'ini_db_user':
    setting => 'db_user',
    value   => $ml_db_user,
  }

  ini_setting { 'ini_db_pwd':
    setting => 'db_password',
    value   => $ml_db_pwd,
  }

  ini_setting { 'ini_max_result_set_size':
    setting => 'max_result_set_size',
    value   => '50',
  }

  ini_setting { 'ini_datetime_format_pattern':
    setting => 'datetime_format_pattern',
    value   => "yyyy-MM-dd'T'HH\:mm\:ss'Z'",
  }

  ini_setting { 'ini_date_format_pattern':
    setting => 'date_format_pattern',
    value   => 'yyyy-MM-dd',
  }

  ini_setting { 'ini_media_server_base_url':
    setting => 'media_server_base_url',
    value   => "https\://${media_server_url}",
  }

  ini_setting { 'ini_db_driver':
    setting => 'db_driver',
    value   => 'com.mysql.jdbc.Driver',
  }

  if $sets == 'hiera_based' {
    create_resources('medialibrary::oaipmh::set', hiera_hash('medialibrary::oaipmh::set', {}))
  }else{
    create_resources('medialibrary::oaipmh::set', parseyaml($sets))
  }

  docker::run {'medialibrary-oai-pmh':
    image   => 'tomcat',
    ports   => "${listen_port}:8080",
    volumes => ['/opt/oai-pmh/extract:/usr/local/tomcat/webapps/ROOT',
                '/var/log/docker-medialibrary-oai-pmh:/usr/local/tomcat/logs'],
    require => File['/opt/oai-pmh/extract'],
  }

}
