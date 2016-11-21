# == Class: medialibrary::deploykey (

#
class medialibrary::deploykey (
  $key,
  $user = 'root'
)
{
  file {'/root/.ssh':
    ensure => 'directory'
  } ->

  file {'/root/.ssh/id_rsa':
    ensure  => present,
    content => $key,
    mode    => '0600',
  } ->

  exec {'/usr/bin/ssh-keyscan github.com >> /root/.ssh/known_hosts':
    unless => '/bin/grep github.com /root/.ssh/known_hosts',
  }
}
