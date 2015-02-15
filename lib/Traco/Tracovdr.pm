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
no if $] >= 5.018, warnings => "experimental";
use Data::Dumper;
use IO::Socket::INET;

#use lib 'lib/';
#use Traco::Svdrpsend ;

use constant {DREISECHSNULLNULL => 3600,SECHSNULL => 60,};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(chkvdrversion parsevdrmarks parsevdrinfo chkvdrfiles bgprocess vdrcut);

$VERSION = '0.25';


sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	bless $self,$class;
	return $self;
} # end sub new

my $tcpsocket;

# process bar
sub bgprocess {
my ( $self,$args ) = @_;
my $line = \$args->{'line'};
my $starttime = \$args->{'starttime'};
my $videoname = \$args->{'videoname'};
my $svdrpsend_flags = \$args->{'svdrpsend_flags'};

#print Dumper $args;

_svdrpsend ({ line=>'open', svdrpsend_flags => ${$svdrpsend_flags} });


#Encoding: task 2 of 2, 18.56 % (24.64 fps, avg 31.18 fps, ETA 01h05m29s)
#				task 1 of 2, 15.05 % (44.52 fps, avg 57.12 fps, ETA 00h33m57s)
my ( $task,$progress,$st );

if (${$line} =~ /^Encoding\:/smx ) {
	( $task,$progress ) = ${$line} =~ m/^Encoding\:\s(.*)\,\s(\d*.\d*)\s/smx ;
	$progress = sprintf ('%.0f',$progress); 
#	print "[bgprocess]_svdrpsend plug bgprocess process traco ${$starttime} $progress $task ${$videoname} -> $dsthost , $dstport , $timeout\n";
	$st = _svdrpsend->({line=>"plug bgprocess process traco ${$starttime} $progress $task ${$videoname}"});
} else {
	$st = _svdrpsend->({line=>"plug bgprocess process traco ${$starttime} 101 task 2 of 2 ${$videoname}"});
}

_svdrpsend ({ line=>'close' });

return $st;
}

#hgl
sub _svdrpsend {
my $args = shift;
my $line = \$args->{'line'};
my @response ;
my $svdrpsend_flags = \$args->{'svdrpsend_flags'};



print {*STDOUT} "[_svdrpsend]send command to VDR ${$line}\n";  


if ( ${$line} =~ /^close$/smx ) {
	_svdrpsend_close ();
	return  ;
}

if ( ${$line} =~ /^open$/smx ) {
	my ($vdrhost,$vdrport,$timeout)  = ${$svdrpsend_flags} =~ m/^[-][d]\s(\d+\.\d+\.\d+\.\d+)\s[-][p]\s(\d+)\s[-][t]\s(\d+)$/smx ;
	if ( not defined $timeout ) { $timeout = '10'; }
	
	print {*STDOUT} "[_svdrpsend]open tcp socket\n";
		$tcpsocket = new IO::Socket::INET (
                                  PeerAddr => $vdrhost,
                                  PeerPort => $vdrport,
				  ReuseAddr => '1',
				  ReusePort => '1',
                                  Proto => 'tcp',
                                  Timeout => $timeout,
                                  Blocking => '1',
                                 ) or croak "[_svdrpsend]Could not create socket: $ERRNO\n" ;

	if ( <$tcpsocket> =~ /^220/smx ) {
		print {*STDOUT} "[_svdrpsend]Connect to VDR $vdrhost Successful\n";  
	} else {
		print {*STDOUT} Dumper <$tcpsocket>;
	}	
}



	print $tcpsocket "${$line}\n" ;

	while ( <$tcpsocket> ) {
		push @response,$_ ;
		if  ( substr ($_, 3, 1) ne '-') {last ; }
	} 

return \@response;
}

sub _svdrpsend_close {
	print $tcpsocket "QUIT\n" ;
	close $tcpsocket or croak "[_svdrpsend] error $ERRNO\n";
	$tcpsocket->shutdown('NOW') ;
return ;
}

sub vdrcut {
my ( $self,$args ) = @_;
#print Dumper $args;
my $dir = \$args->{'dir'};
my $xml = \$args->{'xml'};
my $dbg = \$args->{'debug'};
my $svdrpsend_flags = \$args->{'svdrpsend_flags'};

${$dir} =~ s/\\//gsmx ;


my $title = \$self->getfromxml ({ file => "${$dir}/${$xml}" , field => 'title' , debug => ${$dbg} });

_svdrpsend ({ line => 'open' , svdrpsend_flags => ${$svdrpsend_flags} });
 
my $idx = \ _get_vdr_record_index ( ${$title} );
print {*STDOUT} "[vdrcut]send index no. ${$idx} for cut\n";
#sleep 5;
my $response = _svdrpsend ({line => "EDIT ${$idx}"  });
#print Dumper $response;

_svdrpsend ({line => 'close' });

return  \$response;
}


sub _get_vdr_record_index {
my $title = shift ;

$title =~ s/[_]/ /gsmx;

#print $title . ' ' . $vdrport . ' ' . $vdrhost . ' ' . " \n";
my $lst = _svdrpsend ({line => 'lstr' });

print $title . "\n";

#my @match = map { $_ =~ s/\\//gsmx ; grep ( $title ),$_; } @ { $lst };

my $idx;
for my $m ( @ { $lst } ) {
	$m =~  s/\\//gmsx ;
print $m . "\n";

	if ( $m =~ /$title/ ) { 
		print "$m\n";
		( $idx,undef,undef,undef,undef ) = split /\s/smx,$m ; 
	}
}
$idx =~ s/^\d+[-]//gsmx ;

#print Dumper $idx;
return $idx;


}

# check if exists marks and info file 
# 
sub chkvdrfiles {
my ($self,$args) = @_;

my $dir = \$args->{dir};
my $vdrversion = \$args->{vdrversion};

my $vdr_marks = 'marks';
my $vdr_info = 'info';
my $vdr_index = 'index' ;

if ( ${$vdrversion} =~ /^1[.](?:[3456])$/smx ) {
	$vdr_info='info.vdr';
	$vdr_marks='marks.vdr';
	$vdr_index='index.vdr';
}


my $returnvar = { marks => $vdr_marks, info => $vdr_info, index => $vdr_index, };

if ( ! -e "${$dir}/$vdr_marks" ) { $returnvar->{'marks'} = 'missing'; }
if ( ! -e "${$dir}/$vdr_info" ) { $returnvar->{'info'} = 'missing'; }
if ( ! -e "${$dir}/$vdr_index" ) { $returnvar->{'index'} = 'missing'; }

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

my $readfile = \$self->readfile({file=>"${$markspath}/${$marksfile}",});

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

my $infofile = "${$wrkdir}/info";
my $rcdb = {}; # return db
my $atrack = 0;
my $infopath = ${$wrkdir};


if ( ${$file} ) { $infofile = "${$wrkdir}/${$file}" ; }



my $content = \$self->readfile({file=>$infofile,});

if ( ${$content}->{'returncode'} !~ /[_]done$/smx ) { return ('info_file_not_found') ; };

#foreach my $i ( @{ ${$content}->{'returndata'} } ) {
map {
	
  given ($_) {
    # video
    when ( /^T\s/smx ) {
      my (undef,$title) = split /^[T]\s/smx ,$_;
      while ($title =~ /\s/smx ) {
			$title =~ s/\s/_/smx ;
      }
      $rcdb->{'title'} = $title;
    }
    when ( /^S\s/smx ) {
      my (undef,$epi) = split /^[S]\s/smx ,$_;
      #while ( $epi =~ /\s/smx ) {
 		#	$epi =~ s/\s/_/smx ;
 		#}
 		
 		$rcdb->{'episode'} = $epi;
 	}
    when ( /^D\s/smx ) {
      my (undef,$desc) = split /^[D]\s/smx ,$_;
      #while ( $desc =~ /\s/smx ) {
 		#	$desc =~ s/\s/_/smx ;
 		#}
 		$rcdb->{'description'} = $desc;
 	 } 	
	 when ( /^X\s[1]\s[0](?:[1]|[5])\s/smx ) {
      $rcdb->{'aspect'} = '4:3';
      $rcdb->{'HD'} = q{} ;
    }
    when ( /^X\s[1]\s[0](?:[2]|[3]|[6]|[7])\s/smx ) {
      $rcdb->{'aspect'} = '16:9';
      $rcdb->{'HD'} = q{} ;
    }
    when ( /^X\s[1]\s[0](?:[4]|[8])\s/smx ) {
      $rcdb->{'aspect'} = '>16:9';
      $rcdb->{'HD'} = q{} ;
    }
    when ( /^X\s[1]\s[0](?:[9]|[D])\s/smx ) {
      $rcdb->{'aspect'} = '4:3';
      $rcdb->{'HD'} = 'true' ;
    }
    when ( /^X\s[1]\s[0](?:[A]|[B]|[E]|[F])\s/smx ) {
      $rcdb->{'aspect'} = '16:9';
      $rcdb->{'HD'} = 'true' ;
    }
    when ( /^X\s[1]\s(?:[0][C]|[1][0])\s/smx ) {
      $rcdb->{'aspect'} = '>16:9';
      $rcdb->{'HD'} = 'true' ;
    }
    # audio
    when ( /^X\s[2]\s[0][1]\s/smx ) {
      $rcdb->{"audiotrack$atrack"} = 'mono';
      $atrack++;
    }
    when ( /^X\s[2]\s[0][3]\s/smx ) {
      $rcdb->{"audiotrack$atrack"} = 'stereo';
      $atrack++;
    }
    when ( /^X\s[2]\s[0][5]\s/smx ) {
      $rcdb->{"audiotrack$atrack"} = 'dolby digital';
      $atrack++;
    }
    when ( /^E\s\d+\s\d+\s\d+/smx ) {
      my (undef,$id,$stati,$stoti,undef,undef) = split /\s/smx , $_;
      $rcdb->{'idnr'}= $id ;
      $rcdb->{'starttime'} = $stati ;
      $rcdb->{'duration'} = $stoti ;
    }
    when ( /^F\s\d{2,3}$/smx ) {
      my (undef,$frames) = split /\s/smx , $_;
      $rcdb->{'frames'}= $frames ;
    }
    when ( /^V\s\d+$/smx ) {
      my (undef,$vps) = split /\s/smx , $_;
      $rcdb->{'vpstime'}= $vps ;
    }
  } # end given
} @{ ${$content}->{'returndata'} } ; # end map / foreach @content

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
    
	map {
		if ( $_ =~ /[(]1[.]7[.]/smx )  { $returnline = '1.7'; }
      if ( $_ =~ /[(]1[.]6[.]/smx )  { $returnline = '1.6'; }
	} @{ ${$runexternal}->{'returndata'}} ;
    
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


