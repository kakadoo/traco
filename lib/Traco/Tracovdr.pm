package Traco::Tracovdr;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Traco.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#
use English '-no_match_vars';
use Carp;

use feature qw/switch/;
#use Data::Dumper;
use IO::Socket::INET;

#use lib 'lib/';
#use Traco::Svdrpsend ;

use constant {DREISECHSNULLNULL => 3600,SECHSNULL => 60,};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(chkvdrversion parsevdrmarks parsevdrinfo chkvdrfiles bgprocess);

$VERSION = '0.24';


sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	bless $self,$class;
	return $self;
} # end sub new

# process bar


sub bgprocess {
my ( $self,$args ) = @_;
my $line = \$args->{'line'};
my $starttime = \$args->{'starttime'};
my $videoname = \$args->{'videoname'};
my $svdrpsend_flags = \$args->{'svdrpsend_flags'};

#print Dumper $args;

my ($dsthost,$dstport,$timeout)  = ${$svdrpsend_flags} =~ m/^[-][d]\s(\d+\.\d+\.\d+\.\d+)\s[-][p]\s(\d+)\s[-][t]\s(\d+)$/smx ;
my $svdrpsend = \&_svdrpsend;


#Encoding: task 2 of 2, 18.56 % (24.64 fps, avg 31.18 fps, ETA 01h05m29s)
#				task 1 of 2, 15.05 % (44.52 fps, avg 57.12 fps, ETA 00h33m57s)
my ( $task,$progress,$st );

if (${$line} =~ /^Encoding\:/smx ) {
	( $task,$progress ) = ${$line} =~ m/^Encoding\:\s(.*)\,\s(\d*.\d*)\s/smx ;
	$progress = sprintf ('%.0f',$progress); 
#	print "[bgprocess]_svdrpsend plug bgprocess process traco ${$starttime} $progress $task ${$videoname} -> $dsthost , $dstport , $timeout\n";
	$st = $svdrpsend->({host=>$dsthost,port=>$dstport,timeout=>$timeout,line=>"plug bgprocess process traco ${$starttime} $progress $task ${$videoname}"});
} else {
	$st = $svdrpsend->({host=>$dsthost,port=>$dstport,timeout=>$timeout,line=>"plug bgprocess process traco ${$starttime} 101 task 2 of 2 ${$videoname}"});
}


return $st;
}

sub _svdrpsend {
my $args = shift;
my $line = \$args->{'line'};
my $host = \$args->{'host'};
my $port = \$args->{'port'};
my $timeout = \$args->{'timeout'};
my $ti = ${$timeout} || '10';
my $response ;

#print Dumper $args;

my $tcpsocket = new IO::Socket::INET (
                                  PeerAddr => ${$host},
                                  PeerPort => ${$port},
                                  Proto => 'tcp',
                                  Timeout => $ti,
                                  Blocking => '1',
                                 ) or croak "[_svdrpsend]Could not create socket: $ERRNO\n" ;

#print <$tcpsocket> . "\n";

if ( <$tcpsocket> =~ /^220/smx ) {
#	print "Connect to VDR ${$host} Successful\n";
	print $tcpsocket "${$line}\n" ;
	$response = <$tcpsocket>;
}

#print "[_svdrpsend] $response\n";
	
if ( $response  =~ /OK/smx ) {
	print $tcpsocket "quit\n" ;
	close $tcpsocket or croak "[_svdrpsend] error $ERRNO\n";
#	print "verbindung sollte nun geschlossen sein\n";
} else {
	print '[svdrpsend]' . <$tcpsocket> . "\n";
	print $tcpsocket "quit\n" ;
	close $tcpsocket or croak "[_svdrpsend] error $ERRNO\n";
#	print "verbindung ,mit fehler, sollte nun geschlossen sein\n";
	return '_svdrpsend_error';
}
undef $response;
return '_svdrpsend_done';
}


# check if exists marks and info file 
# 
sub chkvdrfiles {
my ($self,$args) = @_;

my $dir = \$args->{dir};
my $vdrversion = \$args->{vdrversion};

my $vdr_marks = "${$dir}/marks";
my $vdr_info = "${$dir}/info";
my $vdr_index = "${$dir}/index" ;

if ( ${$vdrversion} =~ /^1[.](?:[3456])$/smx ) {
	$vdr_info="${$dir}/info.vdr";
	$vdr_marks="${$dir}/marks.vdr";
	$vdr_index="${$dir}index.vdr";
}


my $returnvar = { marks => $vdr_marks, info => $vdr_info, index => $vdr_index, };

if ( ! -e $vdr_marks ) { $returnvar->{'marks'} = 'missing'; }
if ( ! -e $vdr_info ) { $returnvar->{'info'} = 'missing'; }
if ( ! -e $vdr_index ) { $returnvar->{'index'} = 'missing'; }

#print Dumper $returnvar;
return $returnvar;

}

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

my $readfile = \$self->readfile({file=>${$marksfile},});

if ( ${$readfile}->{'returncode'} =~ /[_]done$/smx ) {
# how may cuts availble
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

if ( -e "${$wrkdir}/info" ) { $infofile="${$wrkdir}/info";}
if ( -e "${$wrkdir}/info.vdr" ) { $infofile="${$wrkdir}/info.vdr";}

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
    when ( $_ =~ /^S\s/smx ) {
      my (undef,$epi) = split /^[S]\s/smx ,$_;
      while ( $epi =~ /\s/smx ) {
 			$epi =~ s/\s/_/smx ;
 		}
 		$rcdb->{'episode'} = $epi;
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
my ( $self,$args) = @_;
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


