#
#
#
class medialibrary::mediaserver (
  $db_host                            ,
  $db_mediaserver_user                ,
  $db_mediaserver_password            ,
  $db_dbname                          ,
  $dataserver_ip                      ,
  $media_server_url                   ,
  $deploykey                          ,
  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',
  $log_directory                      = '/var/log/mediaserver/',
  ) {


  package { 'git':
    ensure => present,
  }
  # Include apache modules with php
  class { 'apache':
    default_mods => true,
    mpm_module   => 'prefork',
  }

  class{ 'apache::mod::php': }
  class{ 'apache::mod::rewrite': }

  apache::vhost { $media_server_url:
      port        => '80',
      docroot     => '/var/www/mediaserver',
      servername  => $media_server_url,
      directories => [{
        path           => '/var/www/mediaserver',
        allow_override => 'All' }
        ],
      require     => Vcsrepo['/var/www/mediaserver'],
  }

  file { [$base_data_dir,
          $base_masters_dir,
          $base_www_dir,
          '/var/www']:
    ensure => directory,
  }

  host { $::hostname :
    ip           => '127.0.0.1',
    host_aliases => [ $::hostname,$media_server_url ],
  }

  class {'::medialibrary::deploykey':
    key => $deploykey,
  }

  vcsrepo { '/var/www/mediaserver':
    ensure   => present,
    provider => 'git',
    source   => 'https://github.com/naturalis/medialibrary-mediaserver'
    #source   => 'git@github.com:naturalis/MediaServer.git',
    #user     => 'root',
    require  => [
      Package['git'],
      Class['::medialibrary::deploykey']
      ],
  }

  file {'/var/www/mediaserver/static.ini':
    ensure  => present,
    mode    => '0666',
    content => template('medialibrary/static.ini.erb'),
    require => Vcsrepo['/var/www/mediaserver'],
  }

  file {$log_directory:
    ensure  => directory,
    mode    => '0660',
    require => Vcsrepo['/var/www/mediaserver'],
    group   => 'www-data',
  }

}
