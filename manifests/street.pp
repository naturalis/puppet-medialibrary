define medialibrary::street(
  $producer               ,
  $mail_to                ,
  $cron_hour              ,
  $cron_minute            ,
  $street                 = $title,
  $owner                  = 'undefined',
  $fileTypes              = 'jpg,jpeg,tiff,tif,png',
  $log_stdout             = 'true',
  $log_level              = 'INFO',
  $mail_onsuccess         = 'true'

) {

  # variables from main (and more general)

  $base_data_dir                      = $medialibrary::harvester::base_data_dir
  $masterDirectory                    = $medialibrary::harvester::base_masters_dir
  $wwwDirectory                       = $medialibrary::harvester::base_www_dir

  $db_host                            = $medialibrary::harvester::db_host
  $db_user                            = $medialibrary::harvester::db_user
  $db_password                        = $medialibrary::harvester::db_password
  $db_dbname                          = $medialibrary::harvester::db_dbname

  $numBackupGroups                    = $medialibrary::harvester::numBackupGroups
  $offload_immediate                  = $medialibrary::harvester::offload_immediate
  $offload_method                     = $medialibrary::harvester::offload_method
  $offload_tar_maxSize                = $medialibrary::harvester::offload_tar_maxSize
  $offload_tar_maxFiles               = $medialibrary::harvester::offload_tar_maxFiles
  $offload_ftp_host                   = $medialibrary::harvester::offload_ftp_host
  $offload_ftp_user                   = $medialibrary::harvester::offload_ftp_user
  $offload_ftp_password               = $medialibrary::harvester::offload_ftp_password
  $offload_ftp_passive                = $medialibrary::harvester::offload_ftp_passive
  $offload_ftp_reconnectPerFile       = $medialibrary::harvester::offload_ftp_reconnectPerFile
  $offload_ftp_maxConnectionAttempts  = $medialibrary::harvester::offload_ftp_maxConnectionAttempts
  $offload_ftp_maxUploadAttempts      = $medialibrary::harvester::offload_ftp_maxUploadAttempts

  $resizeWhen_fileType                = $medialibrary::harvester::resizeWhen_fileType
  $resizeWhen_imageSize               = $medialibrary::harvester::resizeWhen_imageSize

  $imagemagick_convertCommand         = $medialibrary::harvester::imagemagick_convertCommand
  $imagemagick_resizeCommand          = $medialibrary::harvester::imagemagick_resizeCommand
  $imagemagick_maxErrors              = $medialibrary::harvester::imagemagick_maxErrors

  $imagemagick_command                = $medialibrary::harvester::imagemagick_command
  $imagemagick_large_size             = $medialibrary::harvester::imagemagick_large_size
  $imagemagick_large_quality          = $medialibrary::harvester::imagemagick_large_quality
  $imagemagick_medium_size            = $medialibrary::harvester::imagemagick_medium_size
  $imagemagick_medium_quality         = $medialibrary::harvester::imagemagick_medium_quality
  $imagemagick_small_size             = $medialibrary::harvester::imagemagick_small_size
  $imagemagick_small_quality          = $medialibrary::harvester::imagemagick_small_quality

  $cleaner_minDaysOld                 = $medialibrary::harvester::cleaner_minDaysOld
  $cleaner_sweep                      = $medialibrary::harvester::cleaner_sweep
  $cleaner_unixRemove                 = $medialibrary::harvester::cleaner_unixRemove



  #logical derivitives

  $offload_ftp_initDir                = ""
  $debug_maxFiles                     = 0

  $containerDirectory                 = "${medialibrary::harvester::base_data_dir}/${street}.street"
  $publicDirectory                    = "${medialibrary::harvester::base_data_dir}/${street}.street/${street}"
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
    require => File[$medialibrary::harvester::base_data_dir],
  }


  if $offload_method == 'CUSTOM' {
    $offload_command = "tar chPf - \"%local_dir%\" | ncftpput -c -f /etc/medialibrary/ftp.cfg %remote_dir%/%name%"
  }

  $nb = $medialibrary::harvester::numBackupGroups -1

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
    $offload_job = "/bin/bash -c 'for i in {0..${nb}}; do /usr/bin/php /opt/medialibrary/offload.php /etc/medialibrary/config-_backup.ini \$i & ; sleep 5 ; done'"
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
      hour    => $cron_hour,
      minute  => $cron_minute+1,
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
      minute  => "0",
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
