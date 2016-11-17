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
class medialibrary::harvester (
  $cluster_name                       ,

  $base_data_dir                      = '/data',
  $base_www_dir                       = '/data/www',
  $base_masters_dir                   = '/data/masters',

  $db_host                            ,
  $db_user                            ,
  $db_password                        ,
  $db_dbname                          ,

  $numBackupGroups                    = 1,

  $streets                            = hiera_based,

  $offload_immediate                  = 'true',
  $offload_method                     = 'CUSTOM',
  $offload_tar_maxSize                = 1000,
  $offload_tar_maxFiles               = 0,
  $offload_ftp_host                   ,
  $offload_ftp_user                   ,
  $offload_ftp_password               ,
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

  $deploykey                          ,
  #$svn_loc                            = 'svn://dev2.etibioinformatics.nl/NBCMediaLib/MediaPublisher/trunk',
  #$svn_revision                       = 'latest',

  $share_streets                      = false,
  $share_activedirectory_domain       = undef,
  $share_win_domain_admin_user        = undef,
  $share_win_domain_admin_password    = undef,
  ) {

  #package { ['subversion','imagemagick','ncftp','php5','php5-mysql']: ensure => installed, }
  include stdlib

  case $::operatingsystem {
    centos, redhat: {
      package { ['git','ImageMagick','ncftp','php','php-mysql','sendmail']: ensure => installed, }
    }
    debian, ubuntu: {
      package { ['git','imagemagick','ncftp','php5','php5-mysql','sendmail']: ensure => installed, }
    }

    default: {
      fail('Unrecognized operating system')
    }
  }

  file { '/etc/medialibrary': ensure => directory,}

  file { [ $base_data_dir, $base_masters_dir ]:ensure => directory }

  host { $::hostname :
    name         => $::hostname,
    ip           => '127.0.0.1',
    host_aliases => [ $::hostname,$::fqdn ],
  }

  class {'::medialibrary::deploykey':
    key => $deploykey,
  }

  vcsrepo { '/opt/medialibrary':
    ensure   => present,
    provider => 'git',
    source   => 'https://github.com/naturalis/MediaPublisher',
    user     => 'root',
    require  => [Package['git'],Class['::medialibrary::deploykey']],
  }

  # if $svn_revision == 'latest' {
  #
  #   vcsrepo { '/opt/medialibrary':
  #     ensure   => latest,
  #     provider => svn,
  #     source   => $svn_loc,
  #     require  => [ Package['subversion'],Host["${hostname}"] ],
  #   }
  #
  # }else{
  #
  #     vcsrepo { '/opt/medialibrary':
  #     ensure   => present,
  #     provider => svn,
  #     revision => $svn_revision,
  #     source   => $svn_loc,
  #     require  => [ Package['subversion'],Host["${hostname}"] ],
  #   }
  #
  # }

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

  Nfs::Client::Mount <<| nfstag == "${cluster_name}_mediaserver_www_directory" |>> {
    ensure => 'mounted',
    mount  => '/data/www',
  }



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
