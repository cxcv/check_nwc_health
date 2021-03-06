package Classes::CheckPoint::Firewall1::Component::VpnSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->get_snmp_tables('CHECKPOINT-MIB', [
      ['tunnels', 'tunnelTable', 'Classes::CheckPoint::Firewall1::Component::VpnSubsystem::Tunnel', sub { my $o = shift; $o->filter_name($o->{tunnelPeerIpAddr}) || $o->filter_name($o->{tunnelPeerObjName}) } ],
      ['permanenttunnels', 'permanentTunnelTable', 'Classes::CheckPoint::Firewall1::Component::VpnSubsystem::PermanentTunnel, sub { my $o = shift; $o->filter_name($o->{permanentTunnelPeerIpAddr}) || $o->filter_name($o->{permanentTunnelPeerObjName}) }'],
  ]);
}

sub check {
  my $self = shift;
  if (! @{$self->{tunnels}} && ! @{$self->{permanenttunnels}}) {
    $self->add_ok('no tunnels configured');
  } else {
    $self->SUPER::check();
  }
}


package Classes::CheckPoint::Firewall1::Component::VpnSubsystem::Tunnel;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{flat_indices} =~ /^(\d+\.\d+\.\d+\.\d+)/;
  $self->{tunnelPeerIpAddr} ||= $1;
  $self->{tunnelPeerObjName} ||= $self->{tunnelPeerIpAddr};
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'tunnel to %s is %s',
      $self->{tunnelPeerObjName}, $self->{tunnelState});
  if ($self->{tunnelState} =~ /^(destroy|down)$/) {
    $self->add_critical();
  } else {
    $self->add_ok();
  }
}

package Classes::CheckPoint::Firewall1::Component::VpnSubsystem::PermanentTunnel;
our @ISA = qw(Classes::CheckPoint::Firewall1::Component::VpnSubsystem::Tunnel);
use strict;

sub finish {
  my $self = shift;
  $self->{flat_indices} =~ /^(\d+\.\d+\.\d+\.\d+)/;
  $self->{permanentTunnelPeerIpAddr} ||= $1;
  $self->{permanentTunnelPeerObjName} ||= $self->{permanentTunnelPeerIpAddr};
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'permanent tunnel to %s is %s',
      $self->{permanentTunnelPeerObjName}, $self->{permanentTunnelState});
  if ($self->{permanentTunnelState} =~ /^(destroy|down)$/) {
    $self->add_critical();
  } else {
    $self->add_ok();
  }
}


