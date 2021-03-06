package Classes::Cisco::NXOS::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  #$self->mult_snmp_max_msg_size(10);
  $self->bulk_is_baeh(10);
  $self->{sensor_subsystem} =
      Classes::Cisco::CISCOENTITYSENSORMIB::Component::SensorSubsystem->new();
  if ($self->implements_mib('CISCO-ENTITY-FRU-CONTROL-MIB')) {
    $self->{fru_subsystem} = Classes::Cisco::CISCOENTITYFRUCONTROLMIB::Component::EnvironmentalSubsystem->new();
    $self->check_l2_l3();
    foreach my $mod (@{$self->{fru_subsystem}->{module_subsystem}->{modules}}) {
      if (exists $mod->{entity} &&
          $mod->{entity}->{entPhysicalDescr} =~ /L3 DAUGHTER CARD/ &&
          $mod->get_variable('layer', 'l3') eq 'l2') {
        # l3 routing cards may look failed, but the real cause is that the
        # nexus is used as a l2 switch without any routing functionality.
        $mod->blacklist();
        #$self->annotate_info('no l3 routing');
        foreach my $ps (@{$self->{fru_subsystem}->{powersupply_subsystem}->{powersupplies}}) {
          # blacklist also the corresponding power supply which can look like
          # admin status is on, oper status is offDenied
          if ($mod->{flat_indices} eq $ps->{flat_indices}) {
            $ps->blacklist();
          }
        }
      }
    }
  }
}

sub check {
  my $self = shift;
  $self->{sensor_subsystem}->check();
  if (exists $self->{fru_subsystem}) {
    $self->{fru_subsystem}->check();
  }
  if (! $self->check_messages()) {
    $self->clear_ok();
    $self->add_ok("environmental hardware working fine");
  }
}

sub dump {
  my $self = shift;
  $self->{sensor_subsystem}->dump();
  if (exists $self->{fru_subsystem}) {
    $self->{fru_subsystem}->dump();
  }
}

sub check_l2_l3 {
  my $self = shift;
  my @unrealistic_number_of_routes = ();
  for my $masklen (1..12) {
    push(@unrealistic_number_of_routes, 2 ** (32 - $masklen));
  }
  # find out if this device is L2-only (and blacklist offline L3-cpu)
  # ipCidrRouteNumber deprecates ipForwardNumber
  # inetCidrRouteNumber deprecates ipCidrRouteNumber
  my $inetCidrRouteNumber =
      $self->get_snmp_object('IP-FORWARD-MIB', 'inetCidrRouteNumber');
  my $ipCidrRouteNumber =
      $self->get_snmp_object('IP-FORWARD-MIB', 'ipCidrRouteNumber');
  my $ipForwardNumber =
      $self->get_snmp_object('IP-FORWARD-MIB', 'ipForwardNumber');
  my $num_routes = defined $inetCidrRouteNumber ? $inetCidrRouteNumber :
      defined $ipCidrRouteNumber ? $ipCidrRouteNumber :
      defined $ipForwardNumber ? $ipForwardNumber : 0;
  $num_routes = 0 if grep $num_routes, @unrealistic_number_of_routes;
  $self->set_variable("layer", $num_routes ? "l3" : "l2");
}

