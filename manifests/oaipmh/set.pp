define medialibrary::oaipmh::set(
	$producers,  
	$set 					         = $title,
	$max_result_set_size   = '5',
	$format					       = 'medium',
) {
  
  ini_setting { "${set}-ini_producers":
    path    => "/opt/apache-tomcat-${medialibrary::oai-pmh::tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
    section => '',
    key_val_separator => '=',
    setting => "set.${set}.producers",
    value   => $producers,
    ensure  => present,
    require => Exec['clean_default_config'],
  }

  ini_setting { "${set}-ini_max_result_set_size":
    path    => "/opt/apache-tomcat-${medialibrary::oai-pmh::tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
    section => '',
    key_val_separator => '=',
    setting => "set.${set}.max_result_set_size",
    value   => $max_result_set_size,
    ensure  => present,
    require => Exec['clean_default_config'],
  }

  ini_setting { "${set}-ini_format":
    path    => "/opt/apache-tomcat-${medialibrary::oai-pmh::tomcat_version}/webapps/oai-pmh/WEB-INF/classes/config.properties",
    section => '',
    key_val_separator => '=',
    setting => "set.${set}.format",
    value   => $format,
    ensure  => present,
    require => Exec['clean_default_config'],
  }

}