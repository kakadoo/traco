package Traco::Config;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Config.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#
use English '-no_match_vars';
use Carp;

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);

@EXPORT_OK = qw(parseconfig 
						parse_config_value
						);

use constant { FUENF => 5 };

$VERSION = '0.01';

sub new {
	my ($class,$args) = @_;
	my $config = {};
	$class = ref($class) || $class;
#	$config->{'facility'} = 'syslog';
#	$confog->{'priority'} = 'info';

	$config->{'configfile'} = '/etc/vdr/traco.conf' ;
	$config->{'daemon_flag'} = '1';
	$config->{'debug_flag'} = '0';
	$config->{'interval'} = FUENF ;
	$config->{'pidfile'} = '/var/run/vdr/tracosrv.pid';
	$config->{'setcpu'} = 'auto';
	$config->{'fpstype'} = 'vdr';
	$config->{'traco_ts'} = 'vdrtranscode.ts';
	$config->{'traco_xml'} = 'vdrtranscode.xml';
	$config->{'traco_lck'} = 'vdrtranscode.lck';
# set default profile 
	$config->{'defaultprofile'} = 'SD';
# nice default
	$config->{'nice'} = '20';
	$config->{'verbose_flag'} = q{};
	
	$config -> {'facility'} = 'syslog';
	$config -> {'priority'} = 'info' ;
	$config -> {'writelog'} = q{};
	$config -> {'vdr_user'} = 'vdr';

	bless $config,$class;
	return $config;
} # end sub new


sub parseconfig {
my ($self,$args) = @_;
my $file = \$args->{'config'};
my $debug = \$args->{'debug'};
#my $config = {};
my $lines = \$self->readfile({file=>${$file},});

if ( ${$lines}->{'returncode'} !~ /[_]done$/smx ) {
  print {*STDOUT} "trouble to read configfile exit $PROGRAM_NAME\n" or croak $ERRNO ;
  exit 1;
}

  foreach (@{ ${$lines}->{'returndata'} }) {
    s/#.*//smx;     # no comments
    s/^\s+//smx;    # no leading white
    s/\s+$//smx;    # no trailing white
    if ( $_ =~ /^\#/smx ) { next; } ;
    if ( !length ) { next; } ;
    my ($key,$tmp_value) = split /\s*=(?:\s*|\t*)/smx ,$_,2;
    my $value = \$self->parse_config_value({value=>$tmp_value,debug=>${$debug},});
    undef $tmp_value;
    if ( ${$debug} ) { print {*STDOUT} "[DEBUG] _parseconfig | $_\n" or croak $ERRNO; }
    $self->{$key} = ${$value};
  }
  undef $lines;
return ; #$config;
}
sub parse_config_value {
my ($self,$args) = @_;
my $value = \$args->{'value'};
my $debug = \$args->{'debug'};
my $rc = ${$value};
if ( ${$debug} ) { print {*STDOUT} "[DEBUG] _parse_config_value | value = ${$value}\n" or croak $ERRNO; }

if ( ${$value} =~ /^(?:no|NO|[0]|false|false)$/smx ) { $rc = undef; };

return ($rc);
}

1;
