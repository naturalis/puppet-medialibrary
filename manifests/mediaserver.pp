
class medialibrary::mediaserver (
  $db_host                            ,
  $db_mediaserver_user                ,
  $db_mediaserver_password            ,
  $db_dbname                          ,

  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',

  $numBackupGroups                    = 1,

  $offload_immediate                  = 'dummy',
  $offload_method                     = 'dummy',
  $offload_tar_maxSize                = 'dummy',
  $offload_tar_maxFiles               = 'dummy',
  $offload_ftp_host                   = 'dummy',
  $offload_ftp_user                   = 'dummy',
  $offload_ftp_password               = 'dummy',
  $offload_ftp_passive                = 'dummy',
  $offload_ftp_reconnectPerFile       = 'dummy',
  $offload_ftp_maxConnectionAttempts  = 'dummy',
  $offload_ftp_maxUploadAttempts      = 'dummy',

  $resizeWhen_fileType                = 'tiff,jpg,tif,jpeg,gif,png',
  $resizeWhen_imageSize               =  3000,

  $imagemagick_convertCommand         = 'convert \"%s\" \"%s\"',
  $imagemagick_resizeCommand          = 'convert \"%s\" -quality 80 \"%s\"',
  $imagemagick_maxErrors              = 0,

  $imagemagick_command                = 'convert',
  $imagemagick_large_size             = 1920,
  $imagemagick_large_quality          = 100,
  $imagemagick_medium_size            = 500,
  $imagemagick_medium_quality         = 100,
  $imagemagick_small_size             = 100,
  $imagemagick_small_quality          = 100,

  $cleaner_minDaysOld                 = 4,
  $cleaner_sweep                      = 'false',
  $cleaner_unixRemove                 = 'true',

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
      ensure  => 'mounted',
      clients => '10.21.1.18 (rw,insecure,async,no_root_squash)',
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

  apache::vhost { 'medialib_test_2.nnm.local':
      port            => '80',
      docroot         => '/var/www/mediaserver',
      servername      => 'medialib_test_2.nnm.local',
      access_log_file => 'mediaserver_access.log',
      error_log_file  => 'mediaserver_error.log',
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
    host_aliases  => [ $::hostname ],
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
