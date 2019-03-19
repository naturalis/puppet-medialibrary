#
#
#
class medialibrary::dataserver(
  $readwrite_ips   = ['127.0.0.1/32'],
  $readonly_ips = ['127.0.0.1/32'],
  $exported_dirs = ['/data/masters','/data/www'],
  $scriptdir              = '/opt/awsbackup',
  $cronhour               = '19',
  $cronminute             = '0',
  $aws_access_key_id      = 'keyid',
  $aws_secret_access_key  = 'accesskey',
  $aws_bucket             = 'restic-medialibrary-data',
# default check options
  $chkwarninghours                  = 26,
  $chkcriticalhours                 = 48,
  $chkmaxruntimehours               = 48,

)
{

  file { $scriptdir:
    ensure        => 'directory',
  }

  file { '/var/log/aws':
    ensure        => 'directory',
    mode          => '0700'
  }

  file { '/root/.aws':
    ensure        => 'directory',
    mode          => '0700'
  }

  file {"/root/.aws/config":
    ensure        => 'file',
    mode          => '0600',
    content       => template('medialibrary/awsconfig.erb'),
    require       => File['/root/.aws']
  }

  ensure_packages('python-pip')

  ensure_packages(['awscli'], {
    ensure   => present,
    provider => 'pip',
    require  => [ Package['python-pip'], ],
  })

  file {"${scriptdir}/awsbackup.sh":
    ensure        => 'file',
    mode          => '0755',
    content       => template('medialibrary/awsbackup.erb'),
    require       => File[$scriptdir]
  }

  cron { 'awsbackup':
    command       => "${scriptdir}/awsbackup.sh",
    user          => 'root',
    minute        => $cronminute,
    hour          => $cronhour,
    require       => File["${scriptdir}/awsbackup.sh"]
  }

  file { '/etc/logrotate.d/awsbackup':
    ensure        => present,
    mode          => '0644',
    source        => 'puppet:///modules/medialibrary/logrotate_awsbackup',
  }

  $rw_setting = '(rw,insecure,async,no_root_squash)'
  $ro_setting = '(ro,insecure,async,no_root_squash)'
  $rw_array = suffix($readwrite_ips,$rw_setting)
  $ro_array = suffix($readonly_ips,$ro_setting)
  $combined_array = concat($rw_array,$ro_array)
  $export_string = join($combined_array, ' ')

  $directories = concat(['/data'],$exported_dirs)

  include 'docker'

  file { $directories :
    ensure => directory
  }


  class {'::nfs':
    server_enabled => true,
  }

  nfs::server::export{$exported_dirs:
    ensure  => 'mounted',
    clients => $export_string,
  }

# create aws check script for usage with monitoring tools ( sensu )
  file { "${scriptdir}/chkaws.sh":
    ensure                  => 'file',
    mode                    => '0755',
    content                 => template('medialibrary/chkaws.sh.erb'),
    require                 => File[$scriptdir]
  }


# export check so sensu monitoring can make use of it
  @@sensu::check { 'Check aws backup' :
    command => "${scriptdir}/chkaws.sh",
    tag     => 'central_sensu',
  }



}
