package Traco::Tracoadm;
# $Revision: 00001 $
# $Source: /home/glaess/perl/traco/lib/Traco/Tracoadm.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#
#
use English '-no_match_vars';
use Carp;

use feature qw/switch/;
#use Data::Dumper;

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(encodingstatus);

$VERSION = '0.01';

sub encodingsstatus {
my ($self,$args) = @_;
my $debug = \$args->{'debug'};
my $dir = \$args->{'dir'};

#Encoding: task 2 of 2, 18.56 % (24.64 fps, avg 31.18 fps, ETA 01h05m29s)

}

1;
__END__
