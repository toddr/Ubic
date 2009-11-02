package Ubic::PortMap;

use strict;
use warnings;

=head1 NAME

Ubic::PortMap - update and read mapping of ports to service names.

=head1 SYNOPSIS

    use Ubic::PortMap;

    Ubic::PortMap::update();
    print Ubic::PortMap::port2name(12345); # ubic-ping

=head1 METHODS

=over

=cut

use Yandex::Logger;
use Yandex::Persistent;
use Ubic;

use Params::Validate qw(:all);

sub _portmap_file {
    my $ubic_dir = $ENV{UBIC_DIR} || '/var/lib/ubic';
    my $PORTMAP_FILE = $ubic_dir.'/portmap';
    return $PORTMAP_FILE;
}

=item B<< update() >>

Update portmap file.

=cut
sub update {
    validate_pos(@_);

    my $portmap = Yandex::Persistent->new(_portmap_file(), { auto_commit => 0 });
    my %port2service;

   my $process_tree;
    $process_tree = sub {
        my $service = shift() || Ubic->root_service;
        for $_ ($service->services) {
            if ($_->isa('Ubic::Multiservice')) {
                # multiservice
                $process_tree->($_);
            }
            else {
                eval {
                    my $port = $_->port;
                    if ($port) {
                        push @{ $portmap->{$port} }, $_->name;
                    }
                };
                if ($@) {
                    ERROR $@;
                }
            }
        }
        return;
    };

    $process_tree->();

    $portmap->commit();
    undef $portmap;

    return;
}

=item B<< port2name($port) >>

Get service by port.

If there are several services with one port, it will try to find enabled service among them.

=cut
sub port2name($) {
    my ($port) = validate_pos(@_, { regex => qr/^\d+$/ });
    my $portmap = Yandex::Persistent->new(_portmap_file(), { read_only => 0 });
    return unless $portmap->{$port};
    my @names = @{ $portmap->{$port} };
    while (my $name = shift @names) {
        return $name unless @names; # return last service even if it's disabled
        return $name if Ubic->is_enabled($name);
    }
}

=back

=head1 AUTHOR

Vyacheslav Matjukhin <mmcleric@yandex-team.ru>

=cut

1;
