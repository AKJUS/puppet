# = Class: prometheus::exporter::varnishreqs
#
# Periodically export varnish reuqests stats via node-exporter textfile collector.

class prometheus::exporter::varnishreqs (
    VMlib::Ensure $ensure = 'present',
) {
    stdlib::ensure_packages([
        'python3-prometheus-client',
        'python3-requests',
    ])

    file { '/usr/local/bin/varnish-requests-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/varnish/varnish-requests-exporter',
    }

    # Collect every minute
    systemd::timer::job { 'varnish-requests-exporter':
        ensure          => $ensure,
        description     => 'Exports Varnish request metrics',
        command         => '/usr/local/bin/varnish-requests-exporter',
        interval        => {
            start    => 'OnCalendar',
            interval => '*-*-* *:*:00',
        },
        logging_enabled => false,
        user            => 'root',
    }
}
