# role: mathoid
class role::mathoid {
    include mathoid

    $firewall = $facts['networking']['hostname'] =~ /^test1.+$/ ? {
        true    => 'Class[Role::Bastion] or Class[Role::Mediawiki_beta] or Class[Role::Icinga2]',
        default => 'Class[Role::Bastion] or Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Icinga2]',
    }

    $firewall_rules_str = join(
        query_facts($firewall, ['networking'])
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
    ferm::service { 'mathoid':
        proto   => 'tcp',
        port    => '10044',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'mathoid':
        description => 'Mathoid server',
    }
}
