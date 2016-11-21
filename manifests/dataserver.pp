#
#
#
class medialibrary::dataserver(
  $readwrite_ips   = ['127.0.0.1/32'],
  $readonly_ips = ['127.0.0.1/32]'
  )
  $exported_dirs = ['/data/masters','/data/www']
{

  $rw_setting = '(rw,insecure,async,no_root_squash)'
  $ro_setting = '(ro,insecure,async,no_root_squash)'
  $rw_array = suffix($readwrite_ips,$rw_setting)
  $ro_array = suffix($readonly_ips,$ro_setting)
  $combined_array = concat($rw_array,$ro_array)
  $export_string = join($combined_array, ' ')

  class {'::nfs':
    server_enabled => true,
  }

  nfs::server::export{$exported_dirs:
    ensure  => 'mounted',
    clients => $export_string,
  }

}
