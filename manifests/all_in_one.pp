###
######
###
class medialibrary::all_in_one(
  $cluster_name                       ,

  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',

  $dataserver                        = '127.0.0.1',
  $db_host                           = '127.0.0.1',
  $db_user                           = 'medialibrary',
  $db_password                       = 'medialibrary',
  $db_dbname                         = 'medialibrary',

  $numBackupGroups                    = 3,

  $streets                            = hiera_based,

  $offload_immediate                  = 'true',
  $offload_method                     = 'CUSTOM',
  $offload_tar_maxSize                = 1000,
  $offload_tar_maxFiles               = 0,
  $offload_ftp_host                   = '127.0.0.1',
  $offload_ftp_user                   = 'ftp',
  $offload_ftp_password               = 'ftp',
  $offload_ftp_passive                = 'true',
  $offload_ftp_reconnectPerFile       = 'false',
  $offload_ftp_maxConnectionAttempts  = 3,
  $offload_ftp_maxUploadAttempts      = 3,

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

  #$svn_loc                            = 'svn://dev2.etibioinformatics.nl/NBCMediaLib/MediaPublisher/trunk',
  #$svn_revision                       = 'latest',

  $share_streets                      = false,
  $share_activedirectory_domain       = undef,
  $share_win_domain_admin_user        = undef,
  $share_win_domain_admin_password    = undef,
  ) {

  include stdlib

  case $::operatingsystem {
    centos, redhat: {
      package { ['git','ImageMagick','ncftp','php','php-mysql','sendmail']: ensure => installed, }
    }
    debian, ubuntu: {
      package { ['git','imagemagick','ncftp','php5','sendmail','php5-mysql','php5-gd']: ensure => installed, }
    }

    default: {
      fail('Unrecognized operating system')
    }
  }
  
	######## harvester
	
  file { '/etc/medialibrary': ensure => directory,}

  file { [ $base_data_dir, $base_masters_dir, $base_www_dir,
          '/medialibrary-share','/medialibrary-share/staging' ]: ensure => directory }

  vcsrepo { '/opt/medialibrary':
    ensure   => present,
    provider => 'git',
    source   => 'https://github.com/naturalis/medialibrary-publisher',
    require  => [Package['git']],
  }


  file {'/opt/check_offload_logs.sh' :
    ensure  => 'present',
    content => '#!/bin/sh
    if [ `grep $(date "+%Y-%m-%d")  /medialibrary-share/_backup/log/*.Offloader.*.log  | grep ERROR | wc -l` -ne \'0\' ] ;
      then
        grep $(date "+%Y-%m-%d")  /medialibrary-share/_backup/log/*.Offloader.*.log  | grep ERROR ; return 2;
      else
        echo No Errors in backup since $(date "+%Y-%m-%d") ;
     fi',
    mode  => '0775',
  }

  @sensu::check {'check for offload_logs':
    command => '/opt/check_offload_logs.sh',
    require => File['/opt/check_offload_logs.sh'],
    tag     => 'central_sensu'
  }

  file {'/etc/medialibrary/ftp.cfg':
    ensure  => present,
    require => File['/etc/medialibrary'],
    content => template('medialibrary/ftp.cfg.erb')
  }

  if $streets == 'hiera_based' {
    create_resources('medialibrary::street', hiera('medialibrary::street', {}))
  }else{
    create_resources('medialibrary::street', parseyaml($streets))
  }
  
	##### mediaserver
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

  file { ['/var/www']:
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

  file {'/var/www/mediaserver/log':
    ensure  => directory,
    mode    => '0660',
    require => Vcsrepo['/var/www/mediaserver'],
    group   => 'www-data',
  }

}

