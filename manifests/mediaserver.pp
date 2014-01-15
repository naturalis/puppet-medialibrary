# == Class: medialibrary
#
# Full description of class medialibrary here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { medialibrary:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#
class medialibrary::mediaserver (

  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',

  $db_host                            ,
  $db_mediaserver_user                ,
  $db_mediaserver_password            ,
  $db_dbname                          ,

  $numBackupGroups                    = 1,


  $offload_immediate                  = 'dummy',
  $offload_method                     = 'dummy',
  $offload_tar_maxSize                = 'dummy',
  $offload_tar_maxFiles               = 'dummy,
  $offload_ftp_host                   = 'dummy',
  $offload_ftp_user                   = 'dummy'
  $offload_ftp_password               = 'dummy'
  $offload_ftp_passive                = 'dummy',
  $offload_ftp_reconnectPerFile       = 'dummy',
  $offload_ftp_maxConnectionAttempts  = 'dummy',
  $offload_ftp_maxUploadAttempts      = 'dummy,

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

  $log_directory                      = '/var/www/mediaserver/log'
  ) {

  #package { ['subversion','imagemagick','ncftp','php5','php5-mysql']: ensure => installed, }

  case $::operatingsystem {
    centos, redhat: {
      package { ['subversion','ImageMagick','php','php-mysql','php-gd','sendmail']: ensure => installed, }
    }
    debian, ubuntu: {
      package { ['subversion','imagemagick','php5','php5-mysql','sendmail']: ensure => installed, }
    }

    default: {
      fail('Unrecognized operating system')
    }
  }

# Include apache modules with php
  class { 'apache':
    default_mods => true,
  }
  include apache::mod::php

  apache::vhost { "*.80":
      docroot => '/var/www/mediaserver',
      require => Class['apache'],
      access_log_file => "mediaserver_access.log",
      error_log_file => "mediaserver_error.log",
      directories => [ { path => '/var/www/mediaserver', allow_override => 'All' } ],
      require => Vcsrepo['/var/www/mediaserver']
  }



  file { [ $base_data_dir, $base_masters_dir, $base_www_dir,'/var/www' ]:ensure => directory }

  host { "${hostname}":
    name          => $hostname,
    ip            => '127.0.0.1',
    host_aliases  => [ $hostname ],
  }



  if $svn_revision == 'latest' {

    vcsrepo { '/var/www/mediaserver':
      ensure   => latest,
      provider => svn,
      source   => $svn_loc,
      require  => [ Package['subversion'],Host["${hostname}"] ,File['/var/www'] ],
    }

  }else{

      vcsrepo { '/var/www/mediaserver':
      ensure   => present,
      provider => svn,
      revision => $svn_revision,
      source   => $svn_loc,
      require  => [ Package['subversion'],Host["${hostname}"],File['/var/www'] ],
    }

  }

  file {"/var/www/mediaserver/static.ini":
    ensure  => present,
    content => template("medialibrary/static.ini.erb"),
    require => Vcsrepo['/var/www/mediaserver'],
  }

  file {"${log_directory}":
    ensure  => directory,
    mode    => '666',
    require => Vcsrepo['/var/www/mediaserver'],
  }

  #create_resources('medialibrary::street', hiera('medialibrary::street', []))

#  if $share_streets {
#
#    class {'samba::server':
#      workgroup     => 'NNM',
#      server_string => "ml-test",
#      interfaces    => "eth0 lo",
#      security      => 'ads',
#      require       => Host["${hostname}"],
#    }
#
#    class { 'samba::server::ads':
#      winbind_acct    => '',
#      winbind_pass    => '',
#      realm           => '',
#      nsswitch        => true,
#      target_ou       => "Computers",
#      require         => Class['samba::server']
#    }
#  }

}
