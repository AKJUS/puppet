# @summary
#   Installs and configures the Icinga 2 feature ido-pgsql.
#
# @example The ido-pgsql featue requires an existing database and a user with permissions. This example uses the [puppetlab/postgresql](https://forge.puppet.com/puppetlabs/postgresql) module.
#   include icinga2
#   include postgresql::server
#
#   postgresql::server::db { 'icinga2':
#     user     => 'icinga2',
#     password => postgresql::postgresql_password('icinga2', 'supersecret'),
#   }
#
#   class{ 'icinga2::feature::idopgsql':
#     user          => 'icinga2',
#     password      => 'supersecret',
#     database      => 'icinga2',
#     import_schema => true,
#     require       => Postgresql::Server::Db['icinga2']
#   }
#
# @param ensure
#   Set to present enables the feature ido-pgsql, absent disables it.
#
# @param host
#    PostgreSQL database host address.
#
# @param port
#    PostgreSQL database port.
#
# @param user
#    PostgreSQL database user with read/write permission to the icinga database.
#
# @param password
#    PostgreSQL database user's password. The password parameter isn't parsed anymore.
#
# @param database
#    PostgreSQL database name.
#
# @param ssl_mode
#   Enable SSL connection mode.
#
# @param ssl_key_path
#   Location of the private key.
#
# @param ssl_cert_path
#   Location of the certificate.
#
# @param ssl_cacert_path
#   Location of the CA certificate.
#
# @param ssl_key
#   The private key in a base64 encoded string to store in spicified ssl_key_path file.
#
# @param ssl_cert
#   The certificate in a base64 encoded string to store in spicified ssl_cert_path file.
#
# @param ssl_cacert
#   The CA root certificate in a base64 encoded string to store in spicified ssl_cacert_path file.
#
# @param table_prefix
#   PostgreSQL database table prefix.
#
# @param instance_name
#   Unique identifier for the local Icinga 2 instance.
#
# @param instance_description
#   Description of the Icinga 2 instance.
#
# @param enable_ha
#   Enable the high availability functionality. Only valid in a cluster setup.
#
# @param failover_timeout
#   Set the failover timeout in a HA cluster. Must not be lower than 60s.
#
# @param cleanup
#   Hash with items for historical table cleanup.
#
# @param categories
#   Array of information types that should be written to the database.
#
# @param import_schema
#   Whether to import the PostgreSQL schema or not.
#
class icinga2::feature::idopgsql(
  Variant[String, Sensitive[String]]  $password,
  Enum['absent', 'present']           $ensure               = present,
  Stdlib::Host                        $host                 = 'localhost',
  Stdlib::Port::Unprivileged          $port                 = 5432,
  String                              $user                 = 'icinga',
  String                              $database             = 'icinga',
  Optional[Enum['disable', 'allow',
      'prefer', 'verify-full',
      'verify-ca', 'require']]        $ssl_mode             = undef,
  Optional[Stdlib::Absolutepath]      $ssl_key_path         = undef,
  Optional[Stdlib::Absolutepath]      $ssl_cert_path        = undef,
  Optional[Stdlib::Absolutepath]      $ssl_cacert_path      = undef,
  Optional[Stdlib::Base64]            $ssl_key              = undef,
  Optional[Stdlib::Base64]            $ssl_cert             = undef,
  Optional[Stdlib::Base64]            $ssl_cacert           = undef,
  Optional[String]                    $table_prefix         = undef,
  Optional[String]                    $instance_name        = undef,
  Optional[String]                    $instance_description = undef,
  Optional[Boolean]                   $enable_ha            = undef,
  Optional[Icinga2::Interval]         $failover_timeout     = undef,
  Optional[Icinga2::IdoCleanup]       $cleanup              = undef,
  Optional[Array]                     $categories           = undef,
  Boolean                             $import_schema        = false,
) {

  if ! defined(Class['::icinga2']) {
    fail('You must include the icinga2 base class before using any icinga2 feature class!')
  }

  $owner                  = $::icinga2::globals::user
  $group                  = $::icinga2::globals::group
  $conf_dir               = $::icinga2::globals::conf_dir
  $ssl_dir                = $::icinga2::globals::cert_dir
  $ido_pgsql_package_name = $::icinga2::globals::ido_pgsql_package_name
  $ido_pgsql_schema       = $::icinga2::globals::ido_pgsql_schema
  $manage_package         = $::icinga2::manage_package
  $manage_packages        = $::icinga2::manage_packages
  $_notify                = $ensure ? {
    'present' => Class['::icinga2::service'],
    default   => undef,
  }

  $_ssl_key_mode          = '0600'

  $_password              = if $password =~ Sensitive {
    $password
  } else {
    Sensitive($password)
  }

  File {
    owner   => $owner,
    group   => $group,
  }

  # Set defaults for certificate stuff
  if $ssl_key {
    if $ssl_key_path {
      $_ssl_key_path = $ssl_key_path }
    else {
      $_ssl_key_path = "${ssl_dir}/IdoPgsqlConnection_ido-pgsql.key"
    }

    $_ssl_key = $ssl_key

    file { $_ssl_key_path:
      ensure    => file,
      mode      => $_ssl_key_mode,
      content   => $ssl_key,
      show_diff => false,
      tag       => 'icinga2::config::file',
    }
  } else {
    $_ssl_key_path = $ssl_key_path
  }

  if $ssl_cert {
    if $ssl_cert_path {
      $_ssl_cert_path = $ssl_cert_path }
    else {
      $_ssl_cert_path = "${ssl_dir}/IdoPgsqlConnection_ido-pgsql.crt"
    }

    $_ssl_cert = $ssl_cert

    file { $_ssl_cert_path:
      ensure  => file,
      content => $ssl_cert,
      tag     => 'icinga2::config::file',
    }
  } else {
    $_ssl_cert_path = $ssl_cert_path
  }

  if $ssl_cacert {
    if $ssl_cacert_path {
      $_ssl_cacert_path = $ssl_cacert_path }
    else {
      $_ssl_cacert_path = "${ssl_dir}/IdoPgsqlConnection_ido-pgsql_ca.crt"
    }

    $_ssl_cacert = $ssl_cacert

    file { $_ssl_cacert_path:
      ensure  => file,
      content => $ssl_cacert,
      tag     => 'icinga2::config::file',
    }
  } else {
    $_ssl_cacert_path = $ssl_cacert_path
  }

  $attrs = {
    host                  => $host,
    port                  => $port,
    user                  => $user,
    password              => $_password,
    database              => $database,
    ssl_mode              => $ssl_mode,
    ssl_key               => $_ssl_key_path,
    ssl_cert              => $_ssl_cert_path,
    ssl_ca                => $_ssl_cacert_path,
    table_prefix          => $table_prefix,
    instance_name         => $instance_name,
    instance_description  => $instance_description,
    enable_ha             => $enable_ha,
    failover_timeout      => $failover_timeout,
    cleanup               => $cleanup,
    categories            => $categories,
  }

  # install additional package
  if $ido_pgsql_package_name and ($manage_package or $manage_packages) {
    if $::facts['os']['family'] == 'debian' {
      ensure_resources('file', { '/etc/dbconfig-common' => { ensure => directory, owner => 'root', group => 'root' } })
      file { "/etc/dbconfig-common/${ido_pgsql_package_name}.conf":
        ensure  => file,
        content => "dbc_install='false'\ndbc_upgrade='false'\ndbc_remove='false'\n",
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        before  => Package[$ido_pgsql_package_name],
      }
    } # Debian

    package { $ido_pgsql_package_name:
      ensure => installed,
      before => Icinga2::Feature['ido-pgsql'],
    }
  }

  # import db schema
  if $import_schema {
    if $ido_pgsql_package_name and ($manage_package or $manage_packages) {
      Package[$ido_pgsql_package_name] -> Exec['idopgsql-import-schema']
    }

    $_connection = regsubst(join(any2array(delete_undef_values({
        'host='        => $host,
        'sslmode='     => $ssl_mode,
        'sslcert='     => $_ssl_cert_path,
        'sslkey='      => $_ssl_key_path,
        'sslrootcert=' => $_ssl_cacert_path,
        'user='        => $user,
        'port='        => $port,
        'dbname='      => $database,
      })), ' '), '= ', '=', 'G')

    exec { 'idopgsql-import-schema':
      user        => 'root',
      path        => $::facts['path'],
      environment => ["PGPASSWORD=${_password.unwrap}"],
      command     => "psql '${_connection}' -w -f '${ido_pgsql_schema}'",
      unless      => "psql '${_connection}' -w -c 'select version from icinga_dbversion'",
    }
  }

  # create object
  icinga2::object { 'icinga2::object::IdoPgsqlConnection::ido-pgsql':
    object_name => 'ido-pgsql',
    object_type => 'IdoPgsqlConnection',
    attrs       => delete_undef_values($attrs),
    attrs_list  => keys($attrs),
    target      => "${conf_dir}/features-available/ido-pgsql.conf",
    order       => 10,
    notify      => $_notify,
  }

  # import library
  concat::fragment { 'icinga2::feature::ido-pgsql':
    target  => "${conf_dir}/features-available/ido-pgsql.conf",
    content => "library \"db_ido_pgsql\"\n\n",
    order   => '05',
  }

  icinga2::feature { 'ido-pgsql':
    ensure => $ensure,
  }
}
