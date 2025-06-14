# === Class mediawiki::jobrunner
#
# Defines a jobrunner process for jobrunner selected machine only.
class mediawiki::jobrunner {
    include prometheus::exporter::apache

    $port = 9005
    $local_only_port = 9006
    $php_fpm_sock = 'php/fpm-www.sock'

    # Add headers lost by mod_proxy_fastcgi
    # The apache module doesn't pass along to the fastcgi appserver
    # a few headers, like Content-Type and Content-Length.
    # We need to add them back here.
    ::httpd::conf { 'fcgi_headers':
        source   => 'puppet:///modules/mediawiki/fcgi_headers.conf',
        priority => 0,
    }
    # Declare the proxies explicitly with retry=0
    httpd::conf { 'fcgi_proxies':
        ensure  => present,
        content => template('mediawiki/fcgi_proxies.conf.erb')
    }

    class { 'httpd':
        period  => 'daily',
        rotate  => 7,
        modules => [
            'alias',
            'authz_host',
            'autoindex',
            'deflate',
            'dir',
            'expires',
            'headers',
            'mime',
            'rewrite',
            'setenvif',
            'ssl',
            'proxy_fcgi',
        ]
    }

    class { 'httpd::mpm':
        mpm => 'worker',
    }

    # Modules we don't enable.
    httpd::mod_conf { [
        'authz_default',
        'authz_groupfile',
        'cgi',
    ]:
        ensure => absent,
    }

    file { '/srv/mediawiki/rpc':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/rpc',
        owner   => 'www-data',
        group   => 'www-data',
        require => File['/srv/mediawiki/config'],
    }

    httpd::conf { 'jobrunner_port':
        ensure   => present,
        priority => 1,
        content  => inline_template("# This file is managed by Puppet\nListen <%= @port %>\nListen <%= @local_only_port %>\n"),
    }

    httpd::conf { 'jobrunner_timeout':
        ensure   => present,
        priority => 1,
        content  => inline_template("# This file is managed by Puppet\nTimeout 259200\n"),
    }

    httpd::site { 'jobrunner':
        priority => 1,
        content  => template('mediawiki/jobrunner.conf.erb'),
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Changeprop] or Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'jobrunner-9005':
        proto   => 'tcp',
        port    => $port,
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }
    ferm::service { 'jobrunner-9006':
        proto   => 'tcp',
        port    => $local_only_port,
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ['jobrunner.svc.fsslc.wtnet', 'jobrunner-high.svc.fsslc.wtnet', 'videoscaler.svc.fsslc.wtnet'].each |String $domain| {
        monitoring::services { "${domain} HTTP":
            ensure        => present,
            check_command => 'check_curl',
            vars          => {
                address          => $facts['networking']['ip'],
                http_port        => $port,
                http_vhost       => $domain,
                http_uri         => '/healthcheck.php',
                http_ignore_body => true,
            },
        }
    }
}
