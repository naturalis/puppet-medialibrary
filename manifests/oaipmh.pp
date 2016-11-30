class medialibrary::oaipmh (
	$ml_db_url,
	$ml_db_db,
	$ml_db_user,
	$ml_db_pwd,
	$media_server_url,
	$logfile_location                = '/var/log/oai-pmh.log',
	$tomcat_service_start_timeout    = '10',
	$tomcat_link                     = 'http://ftp.nluug.nl/internet/apache/tomcat/tomcat-7/v7.0.50/bin/apache-tomcat-7.0.73.tar.gz',
	#$java_link                       = 'http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jdk-7u51-linux-x64.tar.gz',
  #$java_version                    = '7.51',
  $tomcat_version                  = '7.0.73',
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
    include apache::mod::proxy_html

    apache::vhost { "$external_web_address":
      port                            => '80',
      proxy_pass                      => [{ 'path' => "/${external_web_address_path}", 'url' => 'http://localhost:8080' }],
      proxy_pass_preserve_host        => true,
      proxy_pass_reverse_cookie_path  => [{ 'path' => '/', 'url' => "/oai-pmh" }],
      priority                        => '1',
      docroot                         => '/var/www',
    }

    if $::osfamily == 'RedHat' {

      exec { 'modify ProxyHTMLEnable':
        command => "/bin/sed -i '/ProxyPreserveHost/a \  ProxyHTMLEnable On' /etc/httpd/conf.d/1-${external_web_address}.conf",
        require => File["1-${external_web_address}.conf"],
        unless  => "/bin/grep 'ProxyHTMLEnable On' /etc/httpd/conf.d/1-${external_web_address}.conf",
      }

      exec { 'modify ProxyHTMLURLMap':
        command => "/bin/sed -i '/ProxyHTMLEnable/a \  ProxyHTMLURLMap /oai-pmh /medialib/oai-pmh' /etc/httpd/conf.d/1-${external_web_address}.conf",
        require => Exec['modify ProxyHTMLEnable'],
        notify  => Service['httpd'],
        unless  => "/bin/grep 'ProxyHTMLURLMap /oai-pmh /medialib/oai-pmh' /etc/httpd/conf.d/1-${external_web_address}.conf",
      }

    } elsif $::operatingsystem == 'Ubuntu' {

      exec { 'modify ProxyHTMLEnable':
        command => "/bin/sed -i '/ProxyPreserveHost/a \  SetOutputFilter proxy-html' /etc/apache2/sites-available/1-${external_web_address}.conf",
        require => File["1-${external_web_address}.conf"],
        unless  => "/bin/grep 'ProxyHTMLEnable On' /etc/apache2/sites-available/1-${external_web_address}.conf",
      }

      exec { 'modify ProxyHTMLURLMap':
        command => "/bin/sed -i '/SetOutputFilter/a \  ProxyHTMLURLMap /oai-pmh /medialib/oai-pmh' /etc/apache2/sites-available/1-${external_web_address}.conf",
        require => Exec['modify ProxyHTMLEnable'],
        notify  => Service['httpd'],
        unless  => "/bin/grep 'ProxyHTMLURLMap /oai-pmh /medialib/oai-pmh' /etc/apache2/sites-available/1-${external_web_address}.conf",
      }
    }


  }

	package { 'openjdk-7-jre':
		ensure => installed,
	}
  #$jva = split($java_version, '[.]')
  #$jva_dwn_version = "${jva[0]}u${jva[1]}"
  #$jva_extract_version = "jdk1.${jva[0]}.0_${jva[1]}"
  $tv = split($tomcat_version,'[.]')
  $tv_main = $tv[0]

  #$java_link_real = "http://download.oracle.com/otn-pub/java/jdk/${jva_dwn_version}-b13/jdk-${jva_dwn_version}-linux-x64.tar.gz"
  $tomcat_link_real = "http://ftp.nluug.nl/internet/apache/tomcat/tomcat-${tv_main}/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.tar.gz"


  # exec {"download-java":
  #   command 	=> "/usr/bin/wget --no-check-certificate --no-cookies - --header 'Cookie: oraclelicense=accept-securebackup-cookie' '${java_link_real}' -O /opt/jdk-${jva_dwn_version}-linux-x64.tar.gz",
  #   unless  	=> "/usr/bin/test -f /opt/jdk-${jva_dwn_version}-linux-x64.tar.gz",
  #   returns   => [0,4],
  # }

  exec {"download-tomcat":
    command 	=> "/usr/bin/wget ${tomcat_link_real} -O /opt/apache-tomcat-${tomcat_version}.tar.gz",
    unless  	=> "/usr/bin/test -f /opt/apache-tomcat-${tomcat_version}.tar.gz",
  }

  # exec {"extract-java":
  #   command   => "/bin/tar -xzf /opt/jdk-${jva_dwn_version}-linux-x64.tar.gz",
  #   cwd       => "/opt",
  #   unless    => "/usr/bin/test -d /opt/${jva_extract_version}",
  #   require   => Exec["download-java"],
  # }

  exec {"extract-tomcat":
    command   => "/bin/tar -xzf /opt/apache-tomcat-${tomcat_version}.tar.gz",
    cwd       => "/opt",
    unless    => "/usr/bin/test -d /opt/apache-tomcat-${tomcat_version}",
    require    => Exec["download-tomcat"],
  }

  file {"/etc/init.d/tomcat":
    mode    => '755',
    content => template('medialibrary/tomcat.erb'),
  }

  file {"/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh":
    ensure  => directory,
    require => Exec['extract-tomcat']
  }

  file {"/opt/oai-pmh.war":
    source 	=> "puppet:///modules/medialibrary/oai-pmh.war",
    ensure 	=> "present",
  }

  exec {"extract-war":
    command   => "/opt/${jva_extract_version}/bin/jar xvf /opt/oai-pmh.war",
    cwd       => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh",
    unless    => "/usr/bin/test -f /opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/index.jsp",
    require   => [Exec['extract-tomcat'],
                  Exec['extract-java'],
                  File["/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh"]
                 ],
    notify    => Exec['clean_default_config'],
  }

  exec {'clean_default_config':
    command     => "/bin/rm -fr /opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
    refreshonly => true,
  }

  service { 'tomcat':
    enable    => true,
    ensure    => running,
    require   => [File['/etc/init.d/tomcat'],Exec["extract-tomcat"],Package['openjdk-7-jre']],
    hasstatus => 'false',
    status    => '/bin/ps aux  | /bin/grep apache-tomcat | /bin/grep -v grep',
    start     => '/bin/sh /etc/init.d/tomcat start',
    stop      => '/bin/sh /etc/init.d/tomcat stop',
  }

  # wait some seconds before writing configs.
  # this is because tomcat needs to unpack the war
  #exec {"/bin/sleep ${tomcat_service_start_timeout}":
  #  require => Service['tomcat'],
  #  unless  => '/bin/find /opt/apache-tomcat-7.0.50/webapps/* -maxdepth 0 -cmin +10 | grep oai-pmh.war',
  #}




  file {"/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/logback.xml":
    content	=> template('medialibrary/logback.xml.erb'),
    mode    => '660',
    require => Exec['extract-war'],
  }



  ini_setting { "ini_db_dsn":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'db_dsn',
      value             => "jdbc\:mysql\://${ml_db_url}/${ml_db_db}",
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }

  ini_setting { "ini_db_user":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'db_user',
      value             => $ml_db_user,
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }

  ini_setting { "ini_db_pwd":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'db_password',
      value             => $ml_db_pwd,
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }

  ini_setting { "ini_max_result_set_size":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'max_result_set_size',
      value             => '50',
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }

  ini_setting { "ini_datetime_format_pattern":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'datetime_format_pattern',
      value             => "yyyy-MM-dd'T'HH\:mm\:ss'Z'",
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }

	ini_setting { "ini_date_format_pattern":
			path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
			section           => '',
			key_val_separator => '=',
			setting           => 'date_format_pattern',
			value             => "yyyy-MM-dd",
			ensure            => present,
			require           => Exec['clean_default_config'],
			notify            => Service['tomcat'],
	}

  ini_setting { "ini_media_server_base_url":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'media_server_base_url',
      value             => "http\://${media_server_url}",
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }

  ini_setting { "ini_db_driver":
      path              => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
      section           => '',
      key_val_separator => '=',
      setting           => 'db_driver',
      value             => 'com.mysql.jdbc.Driver',
      ensure            => present,
      require           => Exec['clean_default_config'],
      notify            => Service['tomcat'],
  }



  if $sets == 'hiera_based' {
    create_resources('medialibrary::oaipmh::set', hiera_hash('medialibrary::oaipmh::set', {}))
  }else{
    create_resources('medialibrary::oaipmh::set', parseyaml($sets))
  }



}
