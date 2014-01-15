class medialibrary::oaipmh (
	$ml_db_url,
	$ml_db_db,
	$ml_db_user,
	$ml_db_pwd,
	$media_server_url,
	$logfile_location	       = '/tmp/oaipmh.log',
	$tomcat_service_timeout  = '10',
	$tomcat_link             = 'http://ftp.nluug.nl/internet/apache/tomcat/tomcat-7/v7.0.50/bin/apache-tomcat-7.0.50.tar.gz',
	$java_link               = 'http://download.oracle.com/otn-pub/java/jdk/7/jdk-7-linux-x64.tar.gz',

) {

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
  }

  file {"/opt/apache-tomcat-7.0.50/webapps/oai-pmh.war":
    source 	=> "puppet:///modules/medialibrary/oai-pmh.war",
    ensure 	=> "present",
    require	=> Exec["extract-tomcat"],
  }
  
  exec {"/bin/bash /etc/init.d/tomcat start":
    require	=> [File['/etc/init.d/tomcat'],File['/opt/apache-tomcat-7.0.50/webapps/oai-pmh.war']],
    unless	=> '/bin/ps aux  | /bin/grep apache-tomcat | /bin/grep -v grep'
  }

  # wait some seconds before writing configs. 
  # this is because tomcat needs to unpack the war
  exec {"/bin/sleep ${tomcat_service_timeout}":
    require => Exec['/bin/bash /etc/init.d/tomcat start'],
    unless  => '/sbin/chkconfig | /bin/grep tomcat | /bin/grep on',
  }
  
  exec {"/sbin/chkconfig tomcat on":
    require	=> Exec["/bin/sleep ${tomcat_service_timeout}"],
    unless	=> '/sbin/chkconfig | /bin/grep tomcat | /bin/grep on',
  }


  file {"/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/config.properties":
    content	=> template('medialibrary/config.properties.erb'),
    mode    => '660',
    require => Exec["/bin/sleep ${tomcat_service_timeout}"],
  }

  file {"/opt/apache-tomcat-7.0.50/webapps/oai-pmh/WEB-INF/classes/logback.xml":
    content	=> template('medialibrary/logback.xml.erb'),
    mode    => '660',
    require => Exec["/bin/sleep ${tomcat_service_timeout}"],
  }

  
}
