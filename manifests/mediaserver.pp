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
  $log_level                          = 'DEBUG',
  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',
  $log_directory                      = '/var/log/mediaserver/',
  ) {


  package { ['git','php5-mysql','php5-gd']:
    ensure => present,
  }
  # Include apache modules with php
  class { 'apache':
    default_mods  => true,
    mpm_module    => 'prefork',
    default_vhost => false,
  }

  class{ 'apache::mod::php': }
  class{ 'apache::mod::rewrite': }
  class{ 'apache::mod::xsendfile': }

  apache::vhost { $media_server_url:
      port            => 80,
      docroot         => '/var/www/mediaserver',
      servername      => $media_server_url,
      custom_fragment => "XSendFile on\nXSendFilePath ${base_masters_dir}",
      directories     => [{
          path           => '/var/www/mediaserver',
          allow_override => 'All' }
          ],
      require         => [
          Vcsrepo['/var/www/mediaserver'],
          Package['php5-mysql']
          ],

  }

# SSL vhost at the same domain
  apache::vhost { "${media_server_url} ssl":
    port       => '443',
    servername      => $media_server_url,
    custom_fragment => "XSendFile on\nXSendFilePath ${base_masters_dir}",
    docroot    => '/var/www/mediaserver',
    directories     => [{
        path           => '/var/www/mediaserver',
        allow_override => 'All' }
        ],
    ssl        => true,
    ssl_cert   => '/etc/ssl/certs/STAR_naturalis_nl.pem',
    ssl_key    => '/etc/ssl/private/STAR_naturalis_nl.key',
    require    => Apache::Vhost[$media_server_url],
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

  # class {'::medialibrary::deploykey':
  #   key => $deploykey,
  # }

  vcsrepo { '/var/www/mediaserver':
    ensure   => present,
    provider => 'git',
    source   => 'https://github.com/naturalis/medialibrary-mediaserver',
    #source   => 'git@github.com:naturalis/MediaServer.git',
    #user     => 'root',
    require  => Package['git'],
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

  class {'::nfs':
    client_enabled => true,
    server_enabled => false,
  }

  nfs::client::mount {'/data/www':
    server  => $dataserver_ip,
    share   => '/data/www',
    require => File['/data/www'],
  }

  nfs::client::mount {'/data/masters':
    server  => $dataserver_ip,
    share   => '/data/masters',
    require => File['/data/masters'],
  }

}
