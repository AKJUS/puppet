#
# Definition: postgresql::user
#
# This definition provides a way to manage postgresql users.
#
# Parameters:
#
# Actions:
#   Create/drop user
#
# Requires:
#   Class postgresql::server
#
# Sample Usage:
#  postgresql::user { 'test@host.example.com':
#    ensure   => 'absent',
#    user     => 'test',
#    password => 'pass',
#    cidr     => '127.0.0.1/32',
#    type     => 'host',
#    method   => 'trust',
#    database => 'template1',
#  }
#
# Based upon https://github.com/uggedal/puppet-module-postgresql
#
define postgresql::user(
    String $user,
    Optional[String] $password = undef,
    String $database = 'template1',
    String $type = 'host',
    String $cidr = '127.0.0.1/32',
    String $attrs = '',
    Boolean $master = true,
    VMlib::Ensure $ensure = 'present',
    Optional[String[1]] $method = undef,
    Optional[Numeric] $pgversion     = undef,
) {

    $_pgversion = $pgversion ? {
        undef   => $facts['os']['distro']['codename'] ? {
            'bookworm' => 15,
            'trixie'   => 17,
            default    => fail("unsupported pgversion: ${pgversion}"),
        },
        default => $pgversion,
    }
    $_method = $method.lest || { ($_pgversion >= 15).bool2str('scram-sha-256', 'md5') }

    $pg_hba_file = "/etc/postgresql/${_pgversion}/main/pg_hba.conf"

    # Check if our user exists and store it
    $userexists = "/usr/bin/psql --tuples-only -c \'SELECT rolname FROM pg_catalog.pg_roles;\' | /bin/grep -P \'^ ${user}$\'"
    # Check if our user doesn't own databases, so we can safely drop
    $user_dbs = "/usr/bin/psql --tuples-only --no-align -c \'SELECT COUNT(*) FROM pg_catalog.pg_database JOIN pg_authid ON pg_catalog.pg_database.datdba = pg_authid.oid WHERE rolname = '${user}';\' | grep -e '^0$'"
    $pass_set = "/usr/bin/psql -c \"ALTER ROLE ${user} WITH ${attrs} PASSWORD '${password}';\""

    # xpath expression to identify the user entry in pg_hba.conf
    if $type == 'local' {
        $xpath = "/files${pg_hba_file}/*[type='${type}'][database='${database}'][user='${user}'][method='${_method}']"
    }
    else {
        $xpath = "/files${pg_hba_file}/*[type='${type}'][database='${database}'][user='${user}'][address='${cidr}'][method='${_method}']"
    }

    # Starting with Bookworm passwords are hashed with salted Scram-SHA256. The user is still tested for existance,
    # but no password changes are supported T326325
    $password_md5    = md5("${password}${user}")
    if (versioncmp($facts['os']['release']['major'], '12') >= 0) {
        $password_clause = "LIKE 'SCRAM-SHA-256\\\$4096:%'"
    } else {
        $password_clause = "= 'md5${password_md5}'"
    }
    $password_check = "/usr/bin/psql -Atc \"SELECT 1 FROM pg_authid WHERE rolname = '${user}' AND rolpassword ${password_clause};\" | grep 1"

    if $ensure == 'present' {
        exec { "create_user-${name}":
            command => "/usr/bin/createuser --no-superuser --no-createdb --no-createrole ${user}",
            user    => 'postgres',
            unless  => $userexists,
        }

        # This will not be run on a slave as it is read-only
        if $master and $password {
            exec { "pass_set-${name}":
                command   => $pass_set,
                user      => 'postgres',
                unless    => $password_check,
                subscribe => Exec["create_user-${name}"],
            }
        }

        if $type == 'local' {
            $changes = [
                "set 01/type \'${type}\'",
                "set 01/database \'${database}\'",
                "set 01/user \'${user}\'",
                "set 01/method \'${_method}\'",
            ]
        } else {
            $changes = [
                "set 01/type \'${type}\'",
                "set 01/database \'${database}\'",
                "set 01/user \'${user}\'",
                "set 01/address \'${cidr}\'",
                "set 01/method \'${_method}\'",
            ]
        }

        augeas { "hba_create-${name}":
            context => "/files${pg_hba_file}/",
            changes => $changes,
            onlyif  => "match ${xpath} size == 0",
            notify  => Exec['pgreload'],
        }
    } elsif $ensure == 'absent' {
        exec { "drop_user-${name}":
            command => "/usr/bin/dropuser ${user}",
            user    => 'postgres',
            onlyif  => "${userexists} && ${user_dbs}",
        }

        augeas { "hba_drop-${name}":
            context => "/files${pg_hba_file}/",
            changes => "rm ${xpath}",
            # only if the user exists
            onlyif  => "match ${xpath} size > 0",
            notify  => Exec['pgreload'],
        }
    }
}
