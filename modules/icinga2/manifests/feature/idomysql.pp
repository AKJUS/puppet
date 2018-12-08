# == Class: icinga2::feature::idomysql
#
# This module configures the Icinga 2 feature ido-mysql.
#
# === Parameters
#
# [*ensure*]
#   Set to present enables the feature ido-mysql, absent disables it. Defaults to present.
#
# [*host*]
#    MySQL database host address. Defaults to '127.0.0.1'.
#
# [*port*]
#    MySQL database port. Defaults to '3306'.
#
# [*socket_path*]
#    MySQL socket path.
#
# [*user*]
#    MySQL database user with read/write permission to the icinga database. Defaults to 'icinga'.
#
# [*password*]
#    MySQL database user's password.
#
# [*database*]
#    MySQL database name. Defaults to 'icinga'.
#
# [*enable_ssl*]
#    Either enable or disable SSL/TLS. Other SSL parameters are only affected if this is set to 'true'.
#    Defaults to 'false'.
#
# [*pki*]
#   Provides multiple sources for the certificate, key and ca. Valid parameters are 'puppet' or 'none'.
#   'puppet' copies the key, cert and CAcert from the Puppet ssl directory to the certs directory
#   /var/lib/icinga2/certs on Linux and C:/ProgramData/icinga2/var/lib/icinga2/certs on Windows.
#   'none' does nothing and you either have to manage the files yourself as file resources
#   or use the ssl_key, ssl_cert, ssl_cacert parameters. Defaults to puppet.
#
# [*ssl_key_path*]
#   Location of the private key. Default depends on platform:
#   /var/lib/icinga2/certs/IdoMysqlConnection_ido-mysql.key on Linux
#   C:/ProgramData/icinga2/var/lib/icinga2/certs/IdoMysqlConnection_ido-mysql.key on Windows
#
# [*ssl_cert_path*]
#   Location of the certificate. Default depends on platform:
#   /var/lib/icinga2/certs/IdoMysqlConnection_ido-mysql.crt on Linux
#   C:/ProgramData/icinga2/var/lib/icinga2/certs/IdoMysqlConnection_ido-mysql.crt on Windows
#
# [*ssl_cacert_path*]
#   Location of the CA certificate. Default is:
#   /var/lib/icinga2/certs/IdoMysqlConnection_ido-mysql_ca.crt on Linux
#   C:/ProgramData/icinga2/var/lib/icinga2/certs/IdoMysqlConnection_ido-mysql_ca.crt on Windows
#
# [*ssl_key*]
#   The private key in a base64 encoded string to store in cert directory, file is stored to
#   path spicified in ssl_key_path. This parameter requires pki to be set to 'none'.
#
# [*ssl_cert*]
#   The certificate in a base64 encoded string to store in cert directory, file is  stored to
#   path spicified in ssl_cert_path. This parameter requires pki to be set to 'none'.
#
# [*ssl_cacert*]
#   The CA root certificate in a base64 encoded string to store in cert directory, file is stored
#   to path spicified in ssl_cacert_path. This parameter requires pki to be set to 'none'.
#
# [*ssl_capath*]
#    MySQL SSL trusted SSL CA certificates in PEM format directory path. Only valid if ssl is enabled.
#
# [*ssl_cipher*]
#    MySQL SSL list of allowed ciphers. Only valid if ssl is enabled.
#
# [*table_prefix*]
#   MySQL database table prefix. Icinga defaults to 'icinga_'.
#
# [*instance_name*]
#   Unique identifier for the local Icinga 2 instance. Icinga defaults to 'default'.
#
# [*instance_description*]
#   Description for the Icinga 2 instance.
#
# [*enable_ha*]
#   Enable the high availability functionality. Only valid in a cluster setup. Icinga defaults to 'true'.
#
# [*failover_timeout*]
#   Set the failover timeout in a HA cluster. Must not be lower than 60s. Icinga defaults to '60s'.
#
# [*cleanup*]
#   Hash with items for historical table cleanup.
#
# [*categories*]
#   Array of information types that should be written to the database.
#
# [*import_schema*]
#   Whether to import the MySQL schema or not. Defaults to 'false'.
#
# === Examples
#
# The ido-mysql featue requires an existing database and a user with permissions.
# To install a database server, create databases and manage user permissions we recommend the puppetlabs/mysql module.
# Here's an example how you create a MySQL database with the corresponding user with permissions by usng the
# puppetlabs/mysql module:
#
# include icinga2
# include mysql::server
#
# mysql::db { 'icinga2':
#   user     => 'icinga2',
#   password => 'supersecret',
#   host     => 'localhost',
#   grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'INDEX', 'EXECUTE', 'ALTER'],
# }
#
# class{ 'icinga2::feature::idomysql':
#   user          => "icinga2",
#   password      => "supersecret",
#   database      => "icinga2",
#   import_schema => true,
#   require       => Mysql::Db['icinga2']
# }
#
#
class icinga2::feature::idomysql(
  String                                           $password,
  Enum['absent', 'present']                        $ensure                 = present,
  String                                           $host                   = '127.0.0.1',
  Integer[1,65535]                                 $port                   = 3306,
  Optional[Stdlib::Absolutepath]                   $socket_path            = undef,
  String                                           $user                   = 'icinga',
  String                                           $database               = 'icinga',
  Boolean                                          $enable_ssl             = false,
  Enum['none', 'puppet']                           $pki                    = 'puppet',
  Optional[Stdlib::Absolutepath]                   $ssl_key_path           = undef,
  Optional[Stdlib::Absolutepath]                   $ssl_cert_path          = undef,
  Optional[Stdlib::Absolutepath]                   $ssl_cacert_path        = undef,
  Optional[String]                                 $ssl_key                = undef,
  Optional[String]                                 $ssl_cert               = undef,
  Optional[String]                                 $ssl_cacert             = undef,
  Optional[Stdlib::Absolutepath]                   $ssl_capath             = undef,
  Optional[String]                                 $ssl_cipher             = undef,
  Optional[String]                                 $table_prefix           = undef,
  Optional[String]                                 $instance_name          = undef,
  Optional[String]                                 $instance_description   = undef,
  Optional[Boolean]                                $enable_ha              = undef,
  Optional[Pattern[/^\d+[ms]*$/]]                  $failover_timeout       = undef,
  Optional[Hash[String,Pattern[/^\d+[dhms]*$/]]]   $cleanup                = undef,
  Optional[Array]                                  $categories             = undef,
  Boolean                                          $import_schema          = false,
) {

  if ! defined(Class['::icinga2']) {
    fail('You must include the icinga2 base class before using any icinga2 feature class!')
  }

  $owner                  = $::icinga2::globals::user
  $group                  = $::icinga2::globals::group
  $conf_dir               = $::icinga2::globals::conf_dir
  $ssl_dir                = $::icinga2::globals::cert_dir
  $ido_mysql_package_name = $::icinga2::globals::ido_mysql_package_name
  $ido_mysql_schema       = $::icinga2::globals::ido_mysql_schema
  $manage_package         = $::icinga2::manage_package
  $_ssl_key_mode          = '0600'
  $_notify           = $ensure ? {
    'present' => Class['::icinga2::service'],
    default   => undef,
  }

  File {
    owner   => $owner,
    group   => $group,
  }

  if $enable_ssl {

    # Set defaults for certificate stuff
    if $ssl_key_path {
      $_ssl_key_path = $ssl_key_path}
    else {
      $_ssl_key_path = "${ssl_dir}/IdoMysqlConnection_ido-mysql.key" }
    if $ssl_cert_path {
      $_ssl_cert_path = $ssl_cert_path }
    else {
      $_ssl_cert_path = "${ssl_dir}/IdoMysqlConnection_ido-mysql.crt" }
    if $ssl_cacert_path {
      $_ssl_cacert_path = $ssl_cacert_path }
    else {
      $_ssl_cacert_path = "${ssl_dir}/IdoMysqlConnection_ido-mysql_ca.crt" }

    $attrs_ssl = {
      enable_ssl => $enable_ssl,
      ssl_ca     => $_ssl_cacert_path,
      ssl_cert   => $_ssl_cert_path,
      ssl_key    => $_ssl_key_path,
      ssl_capath => $ssl_capath,
      ssl_cipher => $ssl_cipher,
    }

    case $pki {
      'puppet': {
        file { $_ssl_key_path:
          ensure => file,
          mode   => $_ssl_key_mode,
          source => $::icinga2_puppet_hostprivkey,
          tag    => 'icinga2::config::file',
        }

        file { $_ssl_cert_path:
          ensure => file,
          source => $::icinga2_puppet_hostcert,
          tag    => 'icinga2::config::file',
        }

        file { $_ssl_cacert_path:
          ensure => file,
          source => $::icinga2_puppet_localcacert,
          tag    => 'icinga2::config::file',
        }
      } # puppet

      'none': {
        if $ssl_key {
          $_ssl_key = $ssl_key

          file { $_ssl_key_path:
            ensure  => file,
            mode    => $_ssl_key_mode,
            content => $_ssl_key,
            tag     => 'icinga2::config::file',
          }
        }

        if $ssl_cert {
          $_ssl_cert = $ssl_cert

          file { $_ssl_cert_path:
            ensure  => file,
            content => $_ssl_cert,
            tag     => 'icinga2::config::file',
          }
        }

        if $ssl_cacert {
          $_ssl_cacert = $ssl_cacert

          file { $_ssl_cacert_path:
            ensure  => file,
            content => $_ssl_cacert,
            tag     => 'icinga2::config::file',
          }
        }
      } # none
    } # case pki
  } # enable_ssl
  else {
    $attrs_ssl = { enable_ssl  => $enable_ssl }
  }

  $attrs = {
    host                  => $host,
    port                  => $port,
    socket_path           => $socket_path,
    user                  => $user,
    password              => $password,
    database              => $database,
    table_prefix          => $table_prefix,
    instance_name         => $instance_name,
    instance_description  => $instance_description,
    enable_ha             => $enable_ha,
    failover_timeout      => $failover_timeout,
    cleanup               => $cleanup,
    categories            => $categories,

  }

  # install additional package
  if $ido_mysql_package_name and $manage_package {
    ensure_resources('file', { '/etc/dbconfig-common' => { ensure => directory } })
    file { "/etc/dbconfig-common/${ido_mysql_package_name}.conf":
      ensure  => file,
      content => "dbc_install='false'\ndbc_upgrade='false'\ndbc_remove='false'\n",
      mode    => '0600',
      before  => Package[$ido_mysql_package_name],
    }

    package { $ido_mysql_package_name:
      ensure => installed,
      before => Icinga2::Feature['ido-mysql'],
    }
  }

  # import db schema
  if $import_schema {
    if $ido_mysql_package_name and $manage_package {
      Package[$ido_mysql_package_name] -> Exec['idomysql-import-schema']
    }
    exec { 'idomysql-import-schema':
      user    => 'root',
      path    => $::path,
      command => "mysql -h ${host} -P ${port} -u ${user} -p'${password}' ${database} < ${ido_mysql_schema}",
      unless  => "mysql -h ${host} -P ${port} -u ${user} -p'${password}' ${database} -Ns -e 'select version from icinga_dbversion'",
    }
  }

  # create object
  icinga2::object { 'icinga2::object::IdoMysqlConnection::ido-mysql':
    object_name => 'ido-mysql',
    object_type => 'IdoMysqlConnection',
    attrs       => delete_undef_values(merge($attrs, $attrs_ssl)),
    attrs_list  => concat(keys($attrs), keys($attrs_ssl)),
    target      => "${conf_dir}/features-available/ido-mysql.conf",
    order       => 10,
    notify      => $_notify,
  }

  # import library
  concat::fragment { 'icinga2::feature::ido-mysql':
    target  => "${conf_dir}/features-available/ido-mysql.conf",
    content => "library \"db_ido_mysql\"\n\n",
    order   => '05',
  }

  icinga2::feature { 'ido-mysql':
    ensure  => $ensure,
  }
}
