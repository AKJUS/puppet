# Class: postgresql::postgis
#
# This class installs postgis packages
#
# Parameters:
#
# Actions:
#     Install postgis
#
# Requires:
#
# Sample Usage:
#     include postgresql::postgis
#
class postgresql::postgis(
    VMlib::Ensure $ensure = 'present',
    String $postgresql_postgis_package = $facts['os']['distro']['codename'] ? {
        'bookworm' => 'postgresql-15-postgis-3',
        'trixie'   => 'postgresql-17-postgis-3',
    },
) {
    stdlib::ensure_packages(
        [
            $postgresql_postgis_package,
            "${postgresql_postgis_package}-scripts",
            'postgis',
        ],
        {
            ensure => $ensure,
        },
    )
}
