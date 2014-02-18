class medialibrary::oaipmh (
	$ml_db_url,
	$ml_db_db,
	$ml_db_user,
	$ml_db_pwd,
	$media_server_url,
	$logfile_location                = '/var/log/oai-pmh.log',
	$tomcat_service_start_timeout    = '10',
	$tomcat_link                     = 'http://ftp.nluug.nl/internet/apache/tomcat/tomcat-7/v7.0.50/bin/apache-tomcat-7.0.50.tar.gz',
	$java_link                       = 'http://download.oracle.com/otn-pub/java/jdk/7/jdk-7-linux-x64.tar.gz',
  $sets                            = 'hiera_based',
  $use_proxy                       = true,
  $external_web_address            = 'webservices.naturalis.nl',
  $external_web_address_path       = 'medialib'

) {

  include stdlib

  if $use_proxy {
    include concat::setup
    
    class {'apache':
      default_vhost => false,
    }

    include apache::mod::proxy_http
    include apache::mod::proxy_http

    apache::vhost { "$external_web_address":
      port                            => '80',
      proxy_pass                      => [{ 'path' => "/${external_web_address_path}", 'url' => 'http://localhost:8080/' }],
      proxy_pass_preserve_host        => true,
      proxy_pass_reverse_cookie_path  =>  [{ 'path' => '/', 'url' => "/oai-pmh" }],
      priority                        => '1',
      docroot                         => '/var/www',
    }
  }

  exec {"download-java":
    command 	=> "/usr/bin/wget --no-cookies --no-check-certificate --header 'Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com' '${java_link}' -O /opt/jdk-7.tar.gz",
    unless  	=> "/usr/bin/test -f /opt/jdk-7.tar.gz",
  }
  
  exec {"download-tomcat":
    command 	=> "/usr/bin/wget ${tomcat_link} -O /opt/apache-tomcat-7.0.50.tar.gz",
    unless  	=> "/usr/bin/test -f /opt/apache-tomcat-7.0.50.tar.gz",
  }

  exec {"extract-java":
    command   => "/bin/tar -xzf /opt/jdk-7.tar.gz",
    cwd       => "/opt",
    unless    => "/usr/bin/test -d /opt/jdk1.7.0",
    require   => Exec["download-java"],
  }

  exec {"extract-tomcat":
    command   => "/bin/tar -xzf /opt/apache-tomcat-7.0.50.tar.gz",
    cwd       => "/opt",
    unless    => "/usr/bin/test -d /opt/apache-tomcat-7.0.50",
    require    => Exec["download-tomcat"],
  }

  file {"/etc/init.d/tomcat":
    mode    => '755',
    content => template('medialibrary/tomcat.erb'),
    require => Exec["extract-tomcat"],
  }

  
  file {"/opt/apache-tomcat-7.0.50/webapps/oai-pmh.war":
    source 	=> "puppet:///modules/medialibrary/oai-pmh.war",
    ensure 	=> "present",
    require	=> Exec["extract-tomcat"],
    notify  => Service["tomcat"],
  }

  service { 'tomcat':
    enable    => true,
    ensure    => running,
    require   => [File['/etc/init.d/tomcat'],Exec["extract-tomcat"],Exec["extract-java"]],
    hasstatus => 'false',
    status    => '/bin/ps aux  | /bin/grep apache-tomcat | /bin/grep -v grep',
  }
  
  # wait some seconds before writing configs. 
  # this is because tomcat needs to unpack the war
  #exec {"/bin/sleep ${tomcat_service_start_timeout}":
  #  require => Service['tomcat'],
  #  unless  => '/bin/find /opt/apache-tomcat-7.0.50/webapps/* -maxdepth 0 -cmin +10 | grep oai-pmh.war',
  #}

  exec {"/bin/sleep ${tomcat_service_start_timeout}":
    refreshonly => true,
    subscribe   => Service["tomcat"],
  }

  
  file {"/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/logback.xml":
    content	=> template('medialibrary/logback.xml.erb'),
    mode    => '660',
    require => Exec["/bin/sleep ${tomcat_service_start_timeout}"],
  }

  exec {'clean_default_config':
    command     => '/bin/rm -fr /opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
    subscribe   => Exec["/bin/sleep ${tomcat_service_start_timeout}"],
    refreshonly => true,
  }

  ini_setting { "ini_db_dsn":
      path    => '/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
      section => '',
      key_val_separator => '=',
      setting => 'db_dsn',
      value   => "jdbc\:mysql\://${ml_db_url}/${ml_db_db}",
      ensure  => present,
      require => Exec['clean_default_config'],
  }

  ini_setting { "ini_db_user":
      path    => '/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
      section => '',
      key_val_separator => '=',
      setting => 'db_user',
      value   => $ml_db_user,
      ensure  => present,
      require => Exec['clean_default_config'],
  }

  ini_setting { "ini_db_pwd":
      path    => '/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
      section => '',
      key_val_separator => '=',
      setting => 'db_password',
      value   => $ml_db_pwd,
      ensure  => present,
      require => Exec['clean_default_config'],
  }

  ini_setting { "ini_max_result_set_size":
      path    => '/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
      section => '',
      key_val_separator => '=',
      setting => 'max_result_set_size',
      value   => '50',
      ensure  => present,
      require => Exec['clean_default_config'],
  }

  ini_setting { "ini_date_format_pattern":
      path    => '/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
      section => '',
      key_val_separator => '=',
      setting => 'date_format_pattern',
      value   => "yyyy-MM-dd'T'HH\:mm\:ss'Z'",
      ensure  => present,
      require => Exec['clean_default_config'],
  }

  ini_setting { "ini_media_server_base_url":
      path    => '/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties',
      section => '',
      key_val_separator => '=',
      setting => 'media_server_base_url',
      value   => "http\://${media_server_url}",
      ensure  => present,
      require => Exec['clean_default_config'],
  }



  if $sets == 'hiera_based' {
    create_resources('medialibrary::oaipmh::set', hiera_hash('medialibrary::oaipmh::set', {}))
  }else{
    create_resources('medialibrary::oaipmh::set', parseyaml($sets))
  }


    
}
