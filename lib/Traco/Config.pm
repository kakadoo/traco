package Traco::Config;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Config.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#
use English '-no_match_vars';
use Carp;

use Traco::Tracoio ;
use Data::Dumper ;

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);


@EXPORT_OK = qw(parseconfig parse_config_value);

use constant { FUENF => 5 };

$VERSION = '0.01';

sub new {
	my ($class,$args) = @_;
	my $config = {};
	$class = ref($class) || $class;
	$config -> {'configfile'} = '/etc/vdr/traco.conf' ;
	$config -> {'daemon_flag'} = '1';
	$config -> {'debug_flag'} = '0';
	$config -> {'interval'} = FUENF ;
	$config -> {'pidfile'} = '/var/run/vdr/tracosrv.pid';
	$config -> {'setcpu'} = 'auto';
	$config -> {'maxcpu'} = '2';
	$config -> {'fpstype'} = 'vdr';
	$config -> {'traco_ts'} = 'traco.ts';
	$config -> {'traco_xml'} = 'traco.xml';
	$config -> {'traco_lck'} = 'traco.lck';
	$config -> {'traco_tmp'} = 'traco_tmp';
	
# set default profile 
	$config -> {'defaultprofile'} = 'SD';
# nice default
	$config -> {'nice'} = '20';
	$config -> {'verbose_flag'} = q{};
	$config -> {'use_classic_profile'} = 'no' ;
	$config -> {'facility'} = 'syslog';
	$config -> {'priority'} = 'info' ;
	$config -> {'writelog'} = q{};
	$config -> {'vdr_user'} = 'vdr';
	$config -> {'Indir'}  = '/video';
	$config -> {'Outdir'}  = '/video';
	
	$config -> {'AAC_Bitrate' }  = '192' ;
	$config -> {'DRC' } = '2.5' ; 
	$config -> {'anamorph_encoding' } = '1';
	$config -> {'filenameformat'} = '%t-%e(%d.%m.%y,%vxx%vy,%fps).%c';
	$config -> {'writelog'}  = 'false' ;
	$config -> {'usevdrfps'} = 'true' ; # should be in the future obsolete
	$config -> {'fpstype'} = 'vdr' ; 
	$config -> {'vdrversion'} = '1.7';
	$config -> {'recalculate_bitrate' } = 'true' ;
	$config -> {'debug_getfilelist' } = undef ;
	$config -> {'svdrpsend_flags'} = '-d localhost -p 6419 -t 10';
	
	
	bless $config,$class;

	if ( -e $config->{'configfile'} ) { 
		$config->parseconfig ({ config => $config->{'configfile'},debug => $config->{'debug'} });
	}

	return $config;
} # end sub new


sub parseconfig {
my ($self,$args) = @_;
my $file = \$args->{'config'};
my $debug = \$args->{'debug'};
#my $config = {};
my $lines = \$self->Traco::Tracoio::readfile ({file => ${$file},});

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
    if ( ${$debug} ) { print {*STDOUT} "[DEBUG] parseconfig | $_\n" or croak $ERRNO; }
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

