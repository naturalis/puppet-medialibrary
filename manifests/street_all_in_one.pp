define medialibrary::street_all_in_one(
  $producer               ,
  $mail_to                ,
  $cron_hour              ,
  $cron_minute            ,
  $street                 = $title,
  $owner                  = 'undefined',
  $fileTypes              = 'jpg,jpeg,tiff,tif,png',
  $log_stdout             = 'true',
  $log_level              = 'INFO',
  $mail_onsuccess         = 'true',
  $keep_log_files_days    = 60,

) {

  # variables from main (and more general)

  $base_data_dir                      = $medialibrary::all_in_one::base_data_dir
  $masterDirectory                    = $medialibrary::all_in_one::base_masters_dir
  $wwwDirectory                       = $medialibrary::all_in_one::base_www_dir

  $db_host                            = $medialibrary::all_in_one::db_host
  $db_user                            = $medialibrary::all_in_one::db_user
  $db_password                        = $medialibrary::all_in_one::db_password
  $db_dbname                          = $medialibrary::all_in_one::db_dbname

  $numBackupGroups                    = $medialibrary::all_in_one::numBackupGroups
  $offload_immediate                  = $medialibrary::all_in_one::offload_immediate
  $offload_method                     = $medialibrary::all_in_one::offload_method
  $offload_tar_maxSize                = $medialibrary::all_in_one::offload_tar_maxSize
  $offload_tar_maxFiles               = $medialibrary::all_in_one::offload_tar_maxFiles
  $offload_ftp_host                   = $medialibrary::all_in_one::offload_ftp_host
  $offload_ftp_user                   = $medialibrary::all_in_one::offload_ftp_user
  $offload_ftp_password               = $medialibrary::all_in_one::offload_ftp_password
  $offload_ftp_passive                = $medialibrary::all_in_one::offload_ftp_passive
  $offload_ftp_reconnectPerFile       = $medialibrary::all_in_one::offload_ftp_reconnectPerFile
  $offload_ftp_maxConnectionAttempts  = $medialibrary::all_in_one::offload_ftp_maxConnectionAttempts
  $offload_ftp_maxUploadAttempts      = $medialibrary::all_in_one::offload_ftp_maxUploadAttempts

  $resizeWhen_fileType                = $medialibrary::all_in_one::resizeWhen_fileType
  $resizeWhen_imageSize               = $medialibrary::all_in_one::resizeWhen_imageSize

  $imagemagick_convertCommand         = $medialibrary::all_in_one::imagemagick_convertCommand
  $imagemagick_resizeCommand          = $medialibrary::all_in_one::imagemagick_resizeCommand
  $imagemagick_maxErrors              = $medialibrary::all_in_one::imagemagick_maxErrors

  $imagemagick_command                = $medialibrary::all_in_one::imagemagick_command
  $imagemagick_large_size             = $medialibrary::all_in_one::imagemagick_large_size
  $imagemagick_large_quality          = $medialibrary::all_in_one::imagemagick_large_quality
  $imagemagick_medium_size            = $medialibrary::all_in_one::imagemagick_medium_size
  $imagemagick_medium_quality         = $medialibrary::all_in_one::imagemagick_medium_quality
  $imagemagick_small_size             = $medialibrary::all_in_one::imagemagick_small_size
  $imagemagick_small_quality          = $medialibrary::all_in_one::imagemagick_small_quality

  $cleaner_minDaysOld                 = $medialibrary::all_in_one::cleaner_minDaysOld
  $cleaner_sweep                      = $medialibrary::all_in_one::cleaner_sweep
  $cleaner_unixRemove                 = $medialibrary::all_in_one::cleaner_unixRemove



  #logical derivitives

  $offload_ftp_initDir                = ''
  $debug_maxFiles                     = 0

  $publicDirectory                    = "/medialibrary-share/${street}"
  $harvestDirectory                   = "${publicDirectory}/harvest"
  $duplicatesDirecotry                = "${publicDirectory}/duplicates"
  $resubmitDirectory                  = "${publicDirectory}/resubmit"
  $productionDirectory                = "${publicDirectory}/production"
  $stagingDirectory                   = "/medialibrary-share/staging/${street}"
  $logDirectory                       = "${publicDirectory}/log"
  $deadImagesDirectory                = "${publicDirectory}/errors"

  file { [$publicDirectory,
          $productionDirectory,
          $harvestDirectory,
          $duplicatesDirecotry,
          $resubmitDirectory,
          $stagingDirectory,
          $logDirectory,
          $deadImagesDirectory ]:
    ensure  => directory,
    require => File[$medialibrary::all_in_one::base_data_dir],
  }


  if $offload_method == 'CUSTOM' {
    $offload_command = "tar chPf - \"%local_dir%\" | ncftpput -c -f /etc/medialibrary/ftp.cfg %remote_dir%/%name%"
  }

  $nb = $medialibrary::all_in_one::numBackupGroups -1

#  if !defined(Augeas['cron_offload']) {
#    $offload_job = "for i in {0..${nb}}; do /usr/bin/php /opt/medialibrary/offload.php /etc/medialibrary/config-${street}.ini \$i & ; done"
#    augeas{'cron_offload':
#      context => '/etc/crontab',
#      changes => $offload_job,
#    }

#  }

  file {"/etc/medialibrary/config-${street}.ini":
    ensure  => present,
    content => template("medialibrary/config.ini.erb"),
    require => File['/etc/medialibrary'],
  }

  if !defined(Cron['offload']) {
    $offload_job = "/bin/bash -c 'for i in {0..${nb}}; do (/usr/bin/php /opt/medialibrary/offload.php /etc/medialibrary/config-_backup.ini \$i &) ; sleep 120 ; done'"
    cron { 'offload':
      ensure  => present,
      command => $offload_job,
      user    => root,
      hour    => "1",
      minute  => "0",
    }
  }

  cron { "cron-${street}-harvest":
      ensure  => present,
      command => "/usr/bin/php /opt/medialibrary/harvest.php /etc/medialibrary/config-${street}.ini",
      user    => root,
      hour    => $cron_hour,
      minute  => $cron_minute,
  }

  cron { "cron-${street}-master-www":
      ensure  => present,
      command => "/usr/bin/php /opt/medialibrary/publish-masters.php /etc/medialibrary/config-${street}.ini && /usr/bin/php /opt/medialibrary/publish-www.php /etc/medialibrary/config-${street}.ini",
      user    => root,
      hour    => $cron_hour+1,
      minute  => $cron_minute,
  }

  #cron { "cron-${street}-www":
  #    ensure  => present,
  #    command => "/usr/bin/php /opt/medialibrary/publish-www.php /etc/medialibrary/config-${street}.ini",
  #    user    => root,
  #    hour    => "*",
  #    minute  => "*/10",
  #}

  cron { "cron-${street}-cleanup":
      ensure  => present,
      command => "/usr/bin/php /opt/medialibrary/cleanup.php /etc/medialibrary/config-${street}.ini",
      user    => root,
      hour    => "6",
      minute  => $cron_minute,
  }

  cron { "cron-${street}-logcleanup":
      ensure  => present,
      command => "/usr/bin/find ${logDirectory} -type f -mtime +${keep_log_files_days} -delete",
      user    => root,
      hour    => "6",
      minute  => $cron_minute,
  }

#  @samba::server::share { $street:
#    comment           => "Share for ${street}",
#    path              => $publicDirectory,
#    browsable         => true,
#    writable          => true,
#    write_list        => '@"NNM\Domain Users"',
#    create_mask       => 0770,
#    directory_mask    => 0770,
#    require           => Class['samba::server']
#  }


}
