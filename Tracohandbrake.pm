package Traco::Tracohandbrake;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Tracohandbrake.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use feature qw/switch/;
use File::Basename;

use constant { EINSNULLNULLNULL => 1000,};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(run_handbrake prepare_audio_tracks handbrakeanalyse);

$VERSION = '0.01';

#
# 0.01 inital version
#

sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	my $d = \$args->{'debug'} ;
	bless $self,$class;
	return $self;
} # end sub new



sub run_handbrake {
my ($self,$args) = @_;
my $execline = \$args->{'execline'};
my $dbg = \$args->{'debug'};
my $wrlog = \$args->{'writelog'};
if ( not ( ${$execline} ) ) { return ('noexeclineforhb'); }

my $time_start = \$self->_preparedtime({timeformat=>0,});

  $self->message({msg=>"JOB START -- ${$time_start}",}) ;
  my $jobresult = \$self->_runexternal({line=>${$execline},debug=>${$dbg},writelog=>${$wrlog},});
  for my $l (@{ ${$jobresult}->{'returndata'} } ) {
    $self->message({msg=>"[jobresult]$l",v=>'vvv'});
  }
  my $time_end = \$self->_preparedtime({timeformat=>0,});
  $self->message({msg=>"JOB STOP -- ${$time_end}",}) ;
undef $time_end;
undef $time_start;
return ('hbdone');
}

sub prepare_audio_tracks {
my ($self,$args) = @_;
my $audiotrack = \$args->{'audiotrack'}; # can be ALL or FIRST
my $hbanalyse = \$args->{'hbanalyse'};
my $dbg = \$args->{'debug'};
my $kbps = \$args->{'kbps'};
my $drc=\$args->{'drc'};
my $aac_bitrate=\$args->{'aac_bitrate'};

my $hbopts = {};
$hbopts->{'ac3tracks'} = '0';
$hbopts->{'mp2tracks'} = '0';
$hbopts->{'audiobitrate'} = q{};
$hbopts->{'audioencoder'} = q{};
$hbopts->{'audionormalizer'} = q{};
$hbopts->{'lang'} = q{};
$hbopts->{'kbps'} = q{};
given (${$audiotrack}) {
  when ( /^(?:first|FIRST)$/smx ) {
    $self->message ({msg=>'[prepare_audio_tracks]use just the first audiotrack',v=>'vvv',debug=>${$dbg},});
    $hbopts->{'audiotracks'} = 1;
    if  (exists ${$hbanalyse}->{'audiotrack[0]options'} ) {
    my $audiotrackoptions = ${$hbanalyse}->{'audiotrack[0]options'};
    $hbopts->{'lang'} = $audiotrackoptions->{'lang'};
    if ($audiotrackoptions->{'codec'} =~ /mp2/smx ) {
      $hbopts->{'mp2tracks'}++;
      $hbopts->{'audioencoder'} = 'faac';
#      $hbopts->{'audiobitrate'} = ${$config}->{'AAC_Bitrate'};
#      $hbopts->{'audionormalizer'} = ${$config}->{'DRC'};
      $hbopts->{'audiobitrate'} = ${$aac_bitrate};
      $hbopts->{'audionormalizer'} = ${$drc};
    } elsif ( $audiotrackoptions->{'codec'} =~ /AC3/smx ) {
      $hbopts->{'ac3tracks'}++;
      $hbopts->{'audioencoder'} = 'copy';
      $hbopts->{'audiobitrate'} = 'auto';
      $hbopts->{'audionormalizer'} = '1.0';
      $hbopts->{'kbps'} = $audiotrackoptions->{'bitrate'} ;
    }
    }
  } # end when first
  when ( $_ =~ /^(?:all|ALL)$/smx ) {
    $self->message ({msg=>'[prepare_audio_tracks] use all audiotracks',v=>'vvv',debug=>${$dbg},});
    my $audiotracks = ${$hbanalyse}->{'audiotracks'} -1;
    foreach my $i ( 0 ..$audiotracks ) {
    if (exists ${$hbanalyse}->{"audiotrack[$i]options"} ) {
    my $audiotrackoptions = ${$hbanalyse}->{"audiotrack[$i]options"};
      if ($audiotrackoptions->{'codec'} =~ /mp2/smx ) {
	$hbopts->{'mp2tracks'}++;
	my $t=$i+1;
	$hbopts->{'audiotracks'} .= "$t,";
	$hbopts->{'lang'} .= "$audiotrackoptions->{'lang'},";
	$hbopts->{'audioencoder'} .= 'faac,';
      $hbopts->{'audiobitrate'} = "${$aac_bitrate},";
      $hbopts->{'audionormalizer'} = "${$drc},";
#	$hbopts->{'audiobitrate'} .= "${$config}->{'AAC_Bitrate'},";
#	$hbopts->{'audionormalizer'} .= "${$config}->{'DRC'},";
      } elsif ( $audiotrackoptions->{'codec'} =~ /AC3/smx ) {
	$hbopts->{'ac3tracks'}++;
	my $t=$i+1;
	$hbopts->{'audiotracks'} .= "$t,";
	$hbopts->{'audioencoder'} .= 'copy,';
	$hbopts->{'audiobitrate'} .= 'auto,';
	$hbopts->{'audionormalizer'} .= '1.0,';
	$hbopts->{'lang'} .= "$audiotrackoptions->{'lang'},";
	$hbopts->{'kbps'} .= "$audiotrackoptions->{'bitrate'}," ;
      }
    }
    }
  } # end when all
} # end given $atracks_cmd

if ( $hbopts->{'audiotracks'} ) { $hbopts->{'audiotracks'} =~ s/[,]$//smx ; }
if ( $hbopts->{'audiobitrate'} ) { $hbopts->{'audiobitrate'} =~ s/[,]$//smx ; }
if ( $hbopts->{'audioencoder'} ) { $hbopts->{'audioencoder'} =~ s/[,]$//smx ; }
if ( $hbopts->{'audionormalizer'} ) { $hbopts->{'audionormalizer'} =~ s/[,]$//smx ; }
if ( $hbopts->{'lang'} ) { $hbopts->{'lang'} =~ s/[,]$//smx ; }
if ( $hbopts->{'kbps'} ) { $hbopts->{'kbps'} =~ s/[,]$//smx ; }

return ($hbopts);
}

sub handbrakeanalyse {
my ($self,$args) = @_;
my $file = \$args->{'file'};
my $dbg = \$args->{'debug'};
my $mynice = \$args->{'nice'};
my $handbrake = \$args->{'handbrake'};
my $kbps = \$args->{'kbps'};
my $starttime=\$args->{'starttime'};
my $fpstype=\$args->{'fpstype'};
my $audiotrack = \$args->{'audiotrack'};
my $drc=\$args->{'drc'};
my $aac_bitrate=\$args->{'aac_bitrate'};


#my $returndb = {};
my @tmpdb2;
# prepare special chars in path
my $workfile = ${$file} ;
$workfile =~ s/[&]/\\&/gmisx ;
$workfile =~ s/\'/\\\'/gmisx ;
$workfile =~ s/[:]/\\:/gmisx ;



my $runline = "nice -n ${$mynice} ${$handbrake} --scan";
if ( ${$starttime} )  { $runline .= " --start-at duration:${$starttime}"; }
$runline .= " -i $workfile -o /dev/null -t 0 2>&1";
my $analyse = $self->_runexternal({line=>$runline,debug=>${$dbg},});

# first cut out just lines with the leading + 
my @tmpdb = grep { /(?:^|(?:\s+|\t+))[+]\s/smx } @{$analyse->{'returndata'}};

# remove trailing +
# beachte map veraendert per default nicht den interen $_
@tmpdb = map { do { (my $a = $_) =~ s/(?:^|(?:\s+|\t+))[+]\s+//smx; $a } } @tmpdb ;
## now prepare and add the lines for returndb without ,
@tmpdb2 = map { split /[,](?:\s+|\t+)/smx,$_ } @tmpdb;
my $pattern1 = '(?:size|pixel\saspect|display\saspect|autocrop|duration)';
my @stage1options = grep { /^($pattern1)[:]\s/smx } @tmpdb2;
my @stage3options = grep { /fps/smx } @tmpdb2;

# prepare Chapter , Audio , Subtitle
my $returndb = $self->_handbrakeanalyse_cas({cas=>\@tmpdb,kbps=>${$kbps},debug=>${$dbg},});

$returndb->{'audioopts'} = $self->prepare_audio_tracks({audiotrack=>${$audiotrack},
  hbanalyse=>$returndb,
  kbps=>${$kbps},
  drc=>${$drc},
  aac_bitrate=>${$aac_bitrate},
  audiotrack=>${$audiotrack},
  debug=>${$dbg},});

for my $o (@stage1options) {
    my ($key,$value) = split /[:]\s/smx, $o;
    $returndb->{$key} = $value || q{};
}

for my $o (@stage3options) {
    my ($value,$key) = split /\s/smx ,$o;
    if ( ( $key eq 'fps' ) and ( $value =~ /^\d+.\d+/smx ) ) { $value = sprintf '%.f' , $value; } # handbrake accept only ganzzahl as frame
    $returndb->{$key} = $value || q{};
}

if (${$fpstype} =~ /^(?:vdr|VDR)$/smx ) {
  my $dir = dirname ${$file};
  my $vdrfps = \$self->getfromxml({file=>"$dir/vdrtranscode.xml",
				      field=>'frames',
					block=>'vdrinfo',
					debug=>${$dbg},
					});
  $returndb->{'fps'} = ${$vdrfps}->{'frames'};
}

return ($returndb);
}
sub _handbrakeanalyse_cas {
my ($self,$args) = @_;
my @tmpdb = @{$args->{'cas'}};# cas = ChapterAudioSubtitle
my $kbps=\$args->{'kbps'};
my $dbg=\$args->{'debug'};
my $returndb ;
my $z = 0;
my $chapters=0;
my $audiotracks=0;
my $subtitle=0;

while ($#tmpdb >= $z) {
# handle chapters
  if ($tmpdb[$z] =~ /chapters[:]/smx .. $tmpdb[$z] !~ /audio\stracks[:]/smx ) {
    my $a=$z+1;
    while ( ( exists $tmpdb[$a] ) and ( $tmpdb[$a] !~ /audio\stracks[:]/smx ) ) {
      $tmpdb[$a] =~ s/^\d+[:]\s//smx ; # remove trailling  digit(s):
      $returndb->{"chapter[$chapters]"} = $tmpdb[$a] || q{};
      $chapters++;
      $a++;
    }
  }
  # handle audiotracks
  if ($tmpdb[$z] =~ /audio\stracks[:]/smx .. $tmpdb[$z] !~ /subtitle\stracks[:]/smx ) {
    my $a=$z+1;
    while ( ( exists $tmpdb[$a] ) and ( $tmpdb[$a] !~ /subtitle\stracks[:]/smx ) ) {
      $tmpdb[$a] =~ s/^\d+[,]\s//smx ; # remove trailling  digit(s),

      my $audiodb = \$self->_prepareaudiooptions ({line=>$tmpdb[$a],kbps=>${$kbps},debug=>${$dbg},});
      
      $returndb->{"audiotrack[$audiotracks]"} = $tmpdb[$a] || q{};
      $returndb->{"audiotrack[$audiotracks]options"} = ${$audiodb};
      $audiotracks++;
      $returndb->{'audiotracks'} = $audiotracks;
      $a++;
    }
  }
  # handle subtitle
   if ($tmpdb[$z] =~ /subtitle\stracks[:]/smx .. $tmpdb[$z] !~ /HandBrake\shas\sexited/smx ) {
    my $a=$z+1;
    while ( ( exists $tmpdb[$a] ) and ( $tmpdb[$a] !~ /HandBrake\shas\sexited/smx ) ) {
      $tmpdb[$a] =~ s/^\d+[:]\s//smx ; # remove trailling  digit(s),
      $returndb->{"subtitle[$subtitle]"} = $tmpdb[$a] || q{};
      $subtitle++;
      $a++;
    }
  }
  $z++;
}

return ($returndb);
}

sub _prepareaudiooptions {
my ($self,$args) = @_;
my $line = \$args->{'line'};
my $inkbps = \$args->{'kbps'};
my $returndb = {};

my ($baseline,$frequenz,$bitrate) = split /[,]\s/smx , ${$line};
if ( $frequenz ) { $frequenz =~ s/[H][z]$//smx; } # remove Hz 
if ( $bitrate ) { $bitrate =~ s/[b][p][s]$//smx ; } # remove bps 


my ( $lang , $codec ,$audiotype ,$isolang ) = $baseline =~ /^(\w+)\s+[(](\w+)[)]\s+[(](.+)[)]\s+[(](.+)[)]/smx ;
if ( ( $codec eq 'AC3') and ( ${$inkbps} ) ) {
  $bitrate = $bitrate / EINSNULLNULLNULL ;
}
$returndb->{'lang'} = $lang;
$returndb->{'codec'} = $codec;
$returndb->{'audiotype'} = $audiotype;
$returndb->{'isolang'} = $isolang;
$returndb->{'bitrate'} = $bitrate;
$returndb->{'frequenz'} = $frequenz;
return ($returndb);
}

1;

__END__

=head1 NAME

  Traco::Tracohandbrake

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


