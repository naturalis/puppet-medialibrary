class medialibrary::mlsf (
	$tomcat_service_start_timeout    = '10',
	$java_link                       = 'http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jdk-7u51-linux-x64.tar.gz',
  $java_version                    = '7.51',
  $tomcat_version                  = '7.0.52',
  $sets                            = 'hiera_based',
) {

  include stdlib

  $jva = split($java_version, '[.]')
  $jva_dwn_version = "${jva[0]}u${jva[1]}"
  $jva_extract_version = "jdk1.${jva[0]}.0_${jva[1]}"
  $tv = split($tomcat_version,'[.]')
  $tv_main = $tv[0]

  $java_link_real = "http://download.oracle.com/otn-pub/java/jdk/${jva_dwn_version}-b13/jdk-${jva_dwn_version}-linux-x64.tar.gz"
  $tomcat_link_real = "http://ftp.nluug.nl/internet/apache/tomcat/tomcat-${tv_main}/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.tar.gz"
  

  exec {"download-java":
    command 	=> "/usr/bin/wget --no-check-certificate --no-cookies - --header 'Cookie: oraclelicense=accept-securebackup-cookie' '${java_link_real}' -O /opt/jdk-${jva_dwn_version}-linux-x64.tar.gz",
    unless  	=> "/usr/bin/test -f /opt/jdk-${jva_dwn_version}-linux-x64.tar.gz",
    returns   => [0,4],
  }
  
  exec {"download-tomcat":
    command 	=> "/usr/bin/wget ${tomcat_link_real} -O /opt/apache-tomcat-${tomcat_version}.tar.gz",
    unless  	=> "/usr/bin/test -f /opt/apache-tomcat-${tomcat_version}.tar.gz",
  }

  exec {"extract-java":
    command   => "/bin/tar -xzf /opt/jdk-${jva_dwn_version}-linux-x64.tar.gz",
    cwd       => "/opt",
    unless    => "/usr/bin/test -d /opt/${jva_extract_version}",
    require   => Exec["download-java"],
  }

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

  # file {"/opt/oai-pmh.war":
  #   source 	=> "puppet:///modules/medialibrary/oai-pmh.war",
  #   ensure 	=> "present",
  # }

  # exec {"extract-war":
  #   command   => "/opt/${jva_extract_version}/bin/jar xvf /opt/oai-pmh.war",
  #   cwd       => "/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh",
  #   unless    => "/usr/bin/test -f /opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/index.jsp",
  #   require   => [Exec['extract-tomcat'],
  #                 Exec['extract-java'],
  #                 File["/opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh"]
  #                ],
  #   notify    => Exec['clean_default_config'],
  # }
  
  # exec {'clean_default_config':
  #   command     => "/bin/rm -fr /opt/apache-tomcat-${tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
  #   refreshonly => true,
  # }

  # service { 'tomcat':
  #   enable    => true,
  #   ensure    => running,
  #   require   => [File['/etc/init.d/tomcat'],Exec["extract-tomcat"],Exec["extract-java"]],
  #   hasstatus => 'false',
  #   status    => '/bin/ps aux  | /bin/grep apache-tomcat | /bin/grep -v grep',
  #   start     => '/bin/sh /etc/init.d/tomcat start',
  #   stop      => '/bin/sh /etc/init.d/tomcat stop',
  # }
  
  # wait some seconds before writing configs. 
  # this is because tomcat needs to unpack the war
  #exec {"/bin/sleep ${tomcat_service_start_timeout}":
  #  require => Service['tomcat'],
  #  unless  => '/bin/find /opt/apache-tomcat-7.0.50/webapps/* -maxdepth 0 -cmin +10 | grep oai-pmh.war',
  #}




    
}
