define medialibrary::oaipmh::set(
	$producers,  
	$set 					= $title,
	$max_result_set_size	= '5',
	$format					= 'medium',
) {
  
  ini_setting { "${set}-ini_producers":
    path    => '/tmp/foo.ini',
    section => '',
    key_val_separator => '=',
    setting => "set.${set}.producers",
    value   => $producers,
    ensure  => present,
    require => Exec["/bin/sleep ${tomcat_service_start_timeout}"],
  }

  ini_setting { "${set}-ini_max_result_set_size":
    path    => '/tmp/foo.ini',
    section => '',
    key_val_separator => '=',
    setting => "set.${set}.max_result_set_size",
    value   => $max_result_set_size,
    ensure  => present,
    require => Exec["/bin/sleep ${tomcat_service_start_timeout}"],
  }

  ini_setting { "${set}-ini_format":
    path    => '/tmp/foo.ini',
    section => '',
    key_val_separator => '=',
    setting => "set.${set}.format",
    value   => $format,
    ensure  => present,
    require => Exec["/bin/sleep ${tomcat_service_start_timeout}"],
  }

}