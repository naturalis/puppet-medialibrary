class medialibrary::mediaserver (
  $db_host                            ,
  $db_mediaserver_user                ,
  $db_mediaserver_password            ,
  $db_dbname                          ,

  $media_harvester_ip                 ,

  $media_server_url                   ,

  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',

  $svn_loc                            = 'svn://dev2.etibioinformatics.nl/NBCMediaLib/MediaServer/trunk',
  $svn_revision                       = 'latest',

  $log_directory                      = '/var/www/mediaserver/log',
  ) {

  
  include concat::setup
  include nfs::server
  
  class { 'selinux':
    mode => 'disabled',
  }

  nfs::server::export{ $base_www_dir :
      clients => "${media_harvester_ip}(rw,sync,no_root_squash)",
      nfstag  => 'mediaserver_www_directory',
      require => File[$base_www_dir],
  }

  case $::operatingsystem {
    centos, redhat: {
      package {['subversion',
                'ImageMagick',
                'php-mysql',
                'php-gd',
                'sendmail']:
        ensure => installed,
      }
    }
    debian, ubuntu: {
      package {['subversion',
                'imagemagick',
                'php5-mysql',
                'sendmail']:
        ensure => installed,
      }
    }

    default: {
      fail('Unrecognized operating system')
    }
  }

# Include apache modules with php
  class { 'apache':
    default_mods  => true,
    mpm_module    => 'prefork',
  }

  class{ 'apache::mod::php': 
  }

  apache::vhost { $media_server_url:
      port            => '80',
      docroot         => '/var/www/mediaserver',
      servername      => $media_server_url,
      directories     => [{ path => '/var/www/mediaserver',allow_override => 'All' } ],
      require         => Vcsrepo['/var/www/mediaserver'],
  }

  file { [$base_data_dir,
          $base_masters_dir,
          $base_www_dir,
          '/var/www']:
    ensure => directory,
  }

  host { $::hostname :
    ip            => '127.0.0.1',
    host_aliases  => [ $::hostname,$media_server_url ],
  }



  if $svn_revision == 'latest' {
    vcsrepo { '/var/www/mediaserver':
      ensure   => latest,
      provider => svn,
      source   => $svn_loc,
      require  => [Package['subversion'],Host[$::hostname],File['/var/www']],
    }
  }else{
      vcsrepo { '/var/www/mediaserver':
      ensure   => present,
      provider => svn,
      revision => $svn_revision,
      source   => $svn_loc,
      require  => [Package['subversion'],Host[$::hostname],File['/var/www']],
    }
  }

  file {'/var/www/mediaserver/static.ini':
    ensure  => present,
    mode    => '0666',
    content => template('medialibrary/static.ini.erb'),
    require => Vcsrepo['/var/www/mediaserver'],
  }

  file {$log_directory:
    ensure  => directory,
    mode    => '0666',
    require => Vcsrepo['/var/www/mediaserver'],
  }

}
