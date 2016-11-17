#
#
#
class medialibrary::samba (
  $workgroup            = 'DOMAIN',
  $server_string        = 'Medialibrary Harvester',
  $interfaces           = 'eth0 lo',
  $security             = 'ads',
  $sharename            = 'harvester-share',
  $sharecomment         = 'Share for getting your stuff harvested',
  $path                 = '/medialibrary',
  $read_only            = false,
  $target_ou            = 'Computers',
  $nsswitch             = true,
  $winbindaccount       = 'DomainAdmin',
  $winbindpassword      = 'DomainAdminPass',
  $winbindrealm         = 'DOMAIN',
  $load_printers        = 'No',
  $disable_spoolss      = 'Yes',
  $printing             = 'bsd',
  $printcap_name        = '/dev/null',
  $disable_osprober     = false,
  ){


  file { $path :
    ensure         => 'directory'
  }

  if ($disable_osprober == true){
    file { '/usr/bin/os-prober':
      ensure => 'file',
      mode   => '0640'
    }
  }

  class {'samba::server':
    workgroup       => $workgroup,
    server_string   => $server_string,
    interfaces      => $interfaces,
    security        => $security,
    load_printers   => $load_printers,
    disable_spoolss => $disable_spoolss,
    printing        => $printing,
    printcap_name   => $printcap_name,
  }

  samba::server::share {$sharename:
    comment   => $sharecomment,
    path      => $path,
    read_only => $read_only,
  }

  if $security == 'ads' {
    class { 'samba::server::ads':
      winbind_acct => $winbindaccount,
      winbind_pass => $winbindpassword,
      realm        => $winbindrealm,
      nsswitch     => $nsswitch,
      target_ou    => $target_ou
    }
  }
}
