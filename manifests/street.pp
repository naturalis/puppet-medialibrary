define medialibrary::street(
  $street                 = $title,
  $producer               ,
  $owner                  = 'undefined',
  $fileTypes              = 'jpg,jpeg,tiff,tif,png',
  $log_stdout             = 'true',
  $log_level              = 'INFO',
  $mail_to                ,
  $mail_onsuccess         = 'true'

) {

  # variables from main (and more general)

  $base_data_dir                      = $medialibrary::base_data_dir
  $masterDirectory                    = $medialibrary::base_www_dir
  $wwwDirectory                       = $medialibrary::base_masters_dir

  $db_host                            = $medialibrary::db_host
  $db_user                            = $medialibrary::db_user
  $db_password                        = $medialibrary::db_password
  $db_dbname                          = $medialibrary::db_dbname

  $numBackupGroups                    = $medialibrary::numBackupGroups
  $offload_immediate                  = $medialibrary::offload_immediate
  $offload_method                     = $medialibrary::offload_method
  $offload_tar_maxSize                = $medialibrary::offload_tar_maxSize
  $offload_tar_maxFiles               = $medialibrary::offload_tar_maxFiles
  $offload_ftp_host                   = $medialibrary::offload_ftp_host
  $offload_ftp_user                   = $medialibrary::offload_ftp_user
  $offload_ftp_password               = $medialibrary::offload_ftp_password
  $offload_ftp_passive                = $medialibrary::offload_ftp_passive
  $offload_ftp_reconnectPerFile       = $medialibrary::offload_ftp_reconnectPerFile
  $offload_ftp_maxConnectionAttempts  = $medialibrary::offload_ftp_maxConnectionAttempts
  $offload_ftp_maxUploadAttempts      = $medialibrary::offload_ftp_maxUploadAttempts

  $resizeWhen_fileType                = $medialibrary::resizeWhen_fileType
  $resizeWhen_imageSize               = $medialibrary::resizeWhen_imageSize

  $imagemagick_convertCommand         = $medialibrary::imagemagick_convertCommand
  $imagemagick_resizeCommand          = $medialibrary::imagemagick_resizeCommand
  $imagemagick_maxErrors              = $medialibrary::imagemagick_maxErrors

  $imagemagick_command                = $medialibrary::imagemagick_command
  $imagemagick_large_size             = $medialibrary::imagemagick_large_size
  $imagemagick_large_quality          = $medialibrary::imagemagick_large_quality
  $imagemagick_medium_size            = $medialibrary::imagemagick_medium_size
  $imagemagick_medium_quality         = $medialibrary::imagemagick_medium_quality
  $imagemagick_small_size             = $medialibrary::imagemagick_small_size
  $imagemagick_small_quality          = $medialibrary::imagemagick_small_quality

  $cleaner_minDaysOld                 = $medialibrary::cleaner_minDaysOld
  $cleaner_sweep                      = $medialibrary::cleaner_sweep
  $cleaner_unixRemove                 = $medialibrary::cleaner_unixRemove



  #logical derivitives

  $offload_ftp_initDir                = $producer
  $debug_maxFiles                     = 0

  $containerDirectory                 = "${medialibrary::base_data_dir}/${street}.street"
  $publicDirectory                    = "${medialibrary::base_data_dir}/${street}.street/${street}"
  $harvestDirectory                   = "${publicDirectory}/harvest"
  $duplicatesDirecotry                = "${publicDirectory}/duplicates"
  $resubmitDirectory                  = "${publicDirectory}/resubmit"
  $productionDirectory                = "${publicDirectory}/production"
  $stagingDirectory                   = "${containerDirectory}/staging"
  $logDirectory                       = "${containerDirectory}/log"
  $deadImagesDirectory                = "${publicDirectory}/errors"

  file { [$containerDirectory,
          $publicDirectory,
          $productionDirectory,
          $harvestDirectory,
          $duplicatesDirecotry,
          $resubmitDirectory,
          $stagingDirectory,
          $logDirectory,
          $deadImagesDirectory ]:
    ensure => directory,
    require => File[$medialibrary::base_data_dir],
  }


  if $offload_method == 'CUSTOM' {
    $offload_command = "tar chPf - \"%local_dir%\" | ncftpput -c -f /etc/medialib/ftp.cfg %remote_dir%/%name%"
  }

  $nb = $medialibrary::numBackupGroups -1

#  if !defined(Augeas['cron_offload']) {
#    $offload_job = "for i in {0..${nb}}; do /usr/bin/php /opt/medialibrary/offload.php /etc/medialibrary/config-${street}.ini $i & ; done"
#    augeas{'cron_offload':
#      context => '/etc/crontab',
#      changes => $offload_job,
#    }

#  }

  if !defined(Cron['offload']) {
    $offload_job = "for i in {0..${nb}}; do /usr/bin/php /opt/medialibrary/offload.php /etc/medialibrary/config-${street}.ini $i & ; done"
    cron { 'offload':
      ensure  => present,
      command => $offload_job,
      user    => root,
      hour    => ["18-8"],
      minute  => "*/10",
    }
  }

  file {"/etc/medialibrary/config-${street}.ini":
    ensure  => present,
    content => template("medialibrary/config.ini.erb"),
    require => File['/etc/medialibrary'],
  }

  if $medialibrary::share_streets {

    samba::server::share { $street:
      comment           => "Share for ${street}",
      path              => $publicDirectory,
      browsable         => true,
      writable          => true,
      write_list        => '@"NNM\Domain Users"',
      create_mask       => 0770,
      directory_mask    => 0770,
      require           => Class['samba::server']
    }

  }
}
