package Traco::Tracovdr;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Traco.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use feature qw/switch/;

#use Sys::Hostname;
#use File::Basename;
use Data::Dumper;

use constant { 
		DREISECHSNULLNULL => 3600,
		SECHSNULL => 60,
};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(chkvdrversion parsevdrmarks parsevdrinfo);

$VERSION = '0.01';

#
# 0.01 inital version
# 0.21 add _parse_config_value
#

sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	bless $self,$class;
	return $self;
} # end sub new

# parsing of marks(.vdr) based on 
# http://www.vdr-wiki.de/wiki/index.php/Vdr%285%29#MARKS
sub parsevdrmarks {
my ($self,$args) = @_;

my $markspath = \$args->{'dir'};
my $f = \$args->{'fps'};
my $fps = ${$f} || '25'; # default 25 fps wenn nix uebergeben wird
my $duration = \$args->{'duration'};

my $marksfile = \$args->{'marksfile'};
my $rcdb = {}; # return db
my %cuts;
# [startfps,startime,stopfps,stoptime]
my $readfile = \$self->readfile({file=>${$marksfile},});

if ( ${$readfile}->{'returncode'} =~ /[_]done$/smx ) {
# how many cuts available
$rcdb->{'cutcount'} = 0;
$rcdb->{'totalframes'} = 0;
my $z=0; # starts with line 1
my $n=0;
my @content = @{ ${$readfile}->{'returndata'} };
my ( $hour , $minute , $sec , $frame ) = q{};
while ($#content >= $z) {
  if ($content[$z] ) {
   ( $hour , $minute , $sec , $frame ) = $content[$z] =~ /(\d+):(\d+):(\d+).(\d+)/smx ;
    my $time_in_seconds = ( ( $hour * DREISECHSNULLNULL ) + ( $minute * SECHSNULL ) + $sec ) ;
    my $overall_fps = ( $time_in_seconds * $fps ) + $frame ;
    $rcdb->{"start_fps$n"} = $overall_fps;
    #$rcdb->{"option_start_frame$n"} = "--start-at frame:$overall_fps";
    $rcdb->{"start_time$n"} = $time_in_seconds;
    $cuts{$n}=[$overall_fps,$time_in_seconds];
#    $rcdb->{"start_frame$n"} = $frame;
    $z=$z+2;
    $n++;
  }
}
$z=1; # starts with line 2
$n=0;
( $hour , $minute , $sec , $frame ) = q{};
while  ($#content >= $z) {
  ( $hour , $minute , $sec , $frame ) = $content[$z] =~ /(\d+):(\d+):(\d+).(\d+)/smx ;
  my $time_in_seconds = ( ( ( $hour * SECHSNULL ) * SECHSNULL ) + ( $minute * SECHSNULL ) + $sec ) ;
  my $overall_fps = ( $time_in_seconds * $fps ) + $frame ;
  $rcdb->{"stop_fps$n"} = $overall_fps;
  #$rcdb->{"option_stop_frame$n"} = "--stop-at frame:$overall_fps";
  $rcdb->{"stop_time$n"} = $time_in_seconds;
#  $rcdb->{"stop_frame$n"} = $frame;
	$cuts{$n}->[2]=$overall_fps;
	$cuts{$n}->[3]=$time_in_seconds;
  if ( $rcdb->{"start_fps$n"} ) { $rcdb->{'cutcount'} = $rcdb->{'cutcount'}+1; }
  $z=$z+2;
  $n++;
}
undef @content;
} # if _done

# calculate from all cuts the total frame count
if ( $rcdb->{'cutcount'} >= 0 ) { # markers used
for my $y (0 .. $rcdb->{'cutcount'} ) {
  if ( ( $rcdb->{"start_fps$y"} ) and ( $rcdb->{"stop_fps$y"} ) ) {
    my  $param_stop = $rcdb->{"stop_fps$y"} - $rcdb->{"start_fps$y"} ;
    $rcdb->{'totalframes'} = $param_stop + $rcdb->{'totalframes'}  ;
  }
}
}

if ( $rcdb->{'cutcount'} <= 0 ) { # no markers used 
  my ( $hour , $minute , $sec ) = ${$duration} =~ /(\d+):(\d+):(\d+)/smx;
  $rcdb->{'totalframes'} = ( ( ( $hour * SECHSNULL * SECHSNULL ) + ( $minute * SECHSNULL ) + $sec ) * $fps ) ;
  $self->message({msg=>"[no markers found]\$totalframes are $rcdb->{'totalframes'}",verbose=>'vvv',}) ;
}

#	print Dumper %cuts;
$rcdb->{'cuts'} = \%cuts;
#print Dumper $rcdb;
undef $readfile;
return ($rcdb);
} # end sub parsevdrmarks 


# parsing of info.(vdr) based on 
# http://www.vdr-wiki.de/wiki/index.php/Info.vdr
sub parsevdrinfo {
my ($self,$args) = @_;
my $wrkdir = \$args->{'dir'};
my $dbg = \$args->{'debug'};
my $file = \$args->{'infofile'};

my $infofile = q{};
my $rcdb = {}; # return db
my $atrack = 0;
my $infopath = ${$wrkdir};

if ( -e "$infopath/info" ) { $infofile="$infopath/info";}
if ( -e "$infopath/info.vdr" ) { $infofile="$infopath/info.vdr";}
if ( ${$file} ) { $infofile = ${$file} ; }

#if ($infofile eq q{}) { return () };

my $content = \$self->readfile({file=>$infofile,});
if ( ${$content}->{'returncode'} !~ /[_]done$/smx ) { return ('info_file_not_found') ; };

foreach my $i ( @{ ${$content}->{'returndata'} } ) {
  given ($i) {
    # video
    when ( $_ =~ /^T\s/smx ) {
      my (undef,$title) = split /^[T]\s/smx ,$_;
      while ($title =~ /\s/smx ) {
	$title =~ s/\s/_/smx ;
      }
      $rcdb->{'title'} = $title;
    }
    when ( $_ =~ /^X\s[1]\s[0](?:[1]|[5])\s/smx ) {
      $rcdb->{'aspect'} = '4:3';
      $rcdb->{'HD'} = q{} ;
    }
    when ( $_ =~ /^X\s[1]\s[0](?:[2]|[3]|[6]|[7])\s/smx ) {
      $rcdb->{'aspect'} = '16:9';
      $rcdb->{'HD'} = q{} ;
    }
    when ( $_ =~ /^X\s[1]\s[0](?:[4]|[8])\s/smx ) {
      $rcdb->{'aspect'} = '>16:9';
      $rcdb->{'HD'} = q{} ;
    }
    when ( $_ =~ /^X\s[1]\s[0](?:[9]|[D])\s/smx ) {
      $rcdb->{'aspect'} = '4:3';
      $rcdb->{'HD'} = 'true' ;
    }
    when ( $_ =~ /^X\s[1]\s[0](?:[A]|[B]|[E]|[F])\s/smx ) {
      $rcdb->{'aspect'} = '16:9';
      $rcdb->{'HD'} = 'true' ;
    }
    when ( $_ =~ /^X\s[1]\s(?:[0][C]|[1][0])\s/smx ) {
      $rcdb->{'aspect'} = '>16:9';
      $rcdb->{'HD'} = 'true' ;
    }
    # audio
    when ( $_ =~ /^X\s[2]\s[0][1]\s/smx ) {
      $rcdb->{"audiotrack$atrack"} = 'mono';
      $atrack++;
    }
    when ( $_ =~ /^X\s[2]\s[0][3]\s/smx ) {
      $rcdb->{"audiotrack$atrack"} = 'stereo';
      $atrack++;
    }
    when ( $_ =~ /^X\s[2]\s[0][5]\s/smx ) {
      $rcdb->{"audiotrack$atrack"} = 'dolby digital';
      $atrack++;
    }
    when ( $_ =~ /^E\s\d+\s\d+\s\d+/smx ) {
      my (undef,$id,$stati,$stoti,undef,undef) = split /\s/smx , $_;
      $rcdb->{'idnr'}= $id ;
      $rcdb->{'starttime'} = $stati ;
      $rcdb->{'duration'} = $stoti ;
    }
    when ( $_ =~ /^F\s\d{2,3}$/smx ) {
      my (undef,$frames) = split /\s/smx , $_;
      $rcdb->{'frames'}= $frames ;
    }
    when ( $_ =~ /^V\s\d+$/smx ) {
      my (undef,$vps) = split /\s/smx , $_;
      $rcdb->{'vpstime'}= $vps ;
    }
  } # end given
} # end foreach @content
return ($rcdb);
}

sub chkvdrversion {
my ($self,$args) = @_;
my $debug = \$args->{'debug'};
my $dir = \$args->{'dir'};
my $type = \$args->{'type'};

if ( not ( defined ${$type} ) ) { return ('notypeforchkvdrversion'); }
my $returnline = q{};

given (${$type}) {
  when ( /^prg$/smx ) {
    my $runexternal = \$self->_runexternal({line=>'vdr -V | grep -E vdr',debug=>${$debug},}); # eg. vdr (1.7.18/1.7.18) - The Video Disk Recorder
    for my $v (@{ ${$runexternal}->{'returndata'}} ) {
      if ( $v =~ /[(]1[.]7[.]/smx )  { $returnline = '1.7'; }
      if ( $v =~ /[(]1[.]6[.]/smx )  { $returnline = '1.6'; }
    }
    undef $runexternal;
  }
  when ( /^file$/smx ) {
  }
}
return ($returnline);
}

1;

__END__

=head1 NAME

  Traco::Tracovdr

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

  Holger Glaess (glaess@glaessixs.de)

=head1 VERSION
  
  see $VERSION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS
  
=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 LICENSE AND COPYRIGHT

  by Holger Glaess
  
=cut


