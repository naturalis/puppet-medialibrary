define medialibrary::oaipmh::set(
	$producers,
	$set = $title,
	$max_result_set_size = '5',
	$format= 'medium',
) {

	Ini_setting {
      ensure            => present,
      path              => '/opt/oai-pmh/extract/WEB-INF/classes/config.properties',
      section           => '',
      key_val_separator => '=',
      require           => Exec['/bin/rm -fr /opt/oai-pmh/extract/WEB-INF/classes/config.properties'],
      notify            => Service['docker-medialibrary-oai-pmh'],
  }

  ini_setting { "${set}-ini_producers":
    setting => "set.${set}.producers",
    value   => $producers,
  }

  ini_setting { "${set}-ini_max_result_set_size":
    setting => "set.${set}.max_result_set_size",
    value   => $max_result_set_size,
  }

  ini_setting { "${set}-ini_format":
    setting => "set.${set}.format",
    value   => $format,
    }

}
