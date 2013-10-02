package Traco::Encoder;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Encoder.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#

#
use English '-no_match_vars';
use Carp;

use feature qw/switch/;
#  Data::Dumper;

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(encode scan profile encopts);

sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	my $d = \$args->{'debug'} ;
	$self->{'debug'} = ${$d};
	if ( ${$d} ) { print {*STDOUT} "$PROGRAM_NAME | new | uid = $UID\n" or croak $ERRNO; }
	bless $self,$class;
	return $self;
} # end sub new

sub scan {};

sub encode {};


1;
