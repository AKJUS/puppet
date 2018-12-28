# class: base::packages
class base::packages {
    $packages = [
        'acct',
        'apt-transport-https',
        'coreutils',
        'debian-goodies',
        'git',
        'htop',
        'logrotate',
        'mtr',
        'nano',
        'pigz',
        'ruby',
        'ruby-safe-yaml',
        'screen',
        'strace',
        'tcpdump',
        'vim',
        'wipe',
    ]

    package { $packages:
        ensure => present,
    }

    if os_version('debian >= stretch') {
        require_package('dirmngr')
    }

    # Get rid of this
    package { [ 'apt-listchanges' ]:
        ensure => absent,
    }
}
