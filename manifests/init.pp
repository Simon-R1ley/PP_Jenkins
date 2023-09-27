# @summary A short summary of the purpose of this class
# https://www.youtube.com/watch?v=1bNscYDeH9s - general infor for roles and profiles!
# This module allows for the installation of Jenkins and firewalld configureation which may operate on the same port
# @param jenkinsport information
# @example
# The following structure is adered to: Package, File, Service
#   include jenkins
#
class jenkins (
  String $jenkinsport = '8080', # Default 
) {
  # Installs yum and open jdk 11, ensures the latest - Secure by design as Java 11 is updated
  # but will maintain the security patches
  package {['yum','java-11-openjdk']:
    ensure => latest,
  }
  # Jenkins pkg url added to yumrepo with gpg key 
  yumrepo { 'jenkins':
    ensure   => 'present',
    baseurl  => 'http://pkg.jenkins.io/redhat-stable',
    gpgkey   => 'https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key',
    descr    => 'Jenkins-stable',
    gpgcheck => '1',
    provider => 'inifile',
  }
  # This ensures that Jenkins prerequsites are avalible prior to installing the latest version of jenkins 
  # sudo cat /var/lib/jenkins/secrets/initialAdminPassword - possible improvement to show password
  package { 'jenkins':
    ensure  => latest,
    require => [Package['java-11-openjdk'], Yumrepo['jenkins']],
  }

  file { '/etc/systemd/system/jenkins.service.d/overide.conf':
    ensure  => file,
    content => epp('jenkins/overide.conf.epp', { 'jenkinsport' => $jenkinsport }),
    notify  => Service['jenkins'], # Tells jenkins service a change has occured
    require => Package['jenkins'], # Requieres the package jenkins to be avalible prior to the config being applied
  }

  service { 'jenkins':
    ensure => 'running',
    enable => 'true',
  }
# 
# Resource Type List - Reff: https://www.puppetmodule.info/modules/puppetlabs-stdlib/4.25.1/puppet_types/file_line

  package { 'firewalld':
    ensure => 'installed',
    before => File['/etc/firewalld/services/jenkins.xml'],
  }

  file { '/etc/firewalld/services/jenkins.xml':
    ensure  => file,
    content => epp('jenkins/jenkins.xml.epp', { 'jenkinsport' => $jenkinsport }),
    mode    => '0600',
    owner   => 'root',
    notify  => [
      Service['firewalld'],
      Exec['/bin/firewall-cmd --reload']
    ],
    alias   => 'jenkinsport',
  }

  exec { '/bin/firewall-cmd --reload':
    refreshonly => true,
    notify      => Exec['firewall-cmd --zone=public --add-service=jenkins --permanent'],
    path        => ['/usr/bin', '/usr/sbin', 'man'],
  }

  exec { 'firewall-cmd --zone=public --add-service=jenkins --permanent':
    refreshonly => true,
    path        => ['/usr/bin', '/usr/sbin', '/sbin'],
  }

  service { 'firewalld':
    ensure  => 'running',
    enable  => true,
    require => Package['firewalld'],
  }

  # Developing notes - The Puppet source - puppet:/// ... needs to be created - this is done by
  # editing the fileserverconfig = /etc/puppetlabs/puppet/fileserver.conf on the PE master.
  # For more information see: https://www.puppet.com/docs/puppet/6/config_file_fileserver.html
  # echo of PW at location
}
