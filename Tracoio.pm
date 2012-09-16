package Traco::Tracoio;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Tracoio.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use Cwd;
use feature qw/switch/;
#use File::Find;
use File::Basename;
#use Data::Dumper;
use File::Glob ':glob';
use Fcntl ':flock';
use Config;
use Encode;
use constant {BUFFERSIZE => 32_768, ACHT => 8, DREIZWEI => 32,};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);
@EXPORT_OK = qw(combine_ts readfile writefile _get_files_in_dir _cutfile _getfps);

$VERSION = '0.18';

#
# 0.01 inital version
#

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

sub _getfps {
my ($self,$args) = @_;
my $fpstype = \$args->{'fpstype'};
my $dbg=\$args->{'debug'};
my $dir=\$args->{'dir'};
my $returnline;
my $hb=\$args->{'handbrake'};
my $nice=\$args->{'nice'};
#######
     # um die richtige fps zahl zu haben fuer die berechnung
     given ( ${$fpstype} ) {
      when ( /^vdr$/smx ) {
	my $vdrfps = \$self->getfromxml({file=>"${$dir}/vdrtranscode.xml",
					field=>'frames',
					block=>'vdrinfo',
					debug=>${dbg},
					});
	$returnline=${$vdrfps}->{'frames'};
	undef $vdrfps;
      }
      when ( /^handbrake$/smx ) {
	my $hba = \$self->handbrakeanalyse({file=>"${$dir}/00001.*",
						    nice=>${$nice},
						    handbrake=>${$hb},
						    debug=>${$dbg},
						    });
	$returnline = ${$hba}->{'fps'};
	undef $hba;
     }
    } # end given
####### 
return ($returnline);
}

sub reniceme {
my ($self,$args) = @_;
# print Dumper $args;

     $self->_runexternal({ line=>"renice -n $args->{'nice'} -p $args->{'pid'}", debug=>$args->{'debug_flag'},});
     return;
}
sub combine_ts {
my ($self,$args) = @_;
my $source_ts = \$args->{'source'} ;
my $target_ts = \$args->{'target'};
my $source_ts_dir = ${$source_ts};
#my $fps=\$args->{'fps'};
my $fpstype=\$args->{'fpstype'};
my $dbg=\$args->{'debug'};
my $vdrv = \$args->{'vdrversion'};
my $hb=\$args->{'handbrake'};
my $nice=\$args->{'nice'};
my $marksfile=\$args->{'marksfile'};
my $xmlfile = "${$source_ts}/vdrtranscode.xml";

if ( -e ${$target_ts} ) { return ('target_exist_in_cutfiles') };
if ( not ( ${$vdrv} ) ) { return ('missing_vdr_version_in_cutfiles'); };
if ( not ( ${$marksfile} ) ) { return ('missing_marks_file_in_cutfiles'); };

my $fps=\$self->_getfps({fpstype=>${$fpstype},dir=>${$source_ts},debug=>${$dbg},handbrake=>${$hb},nice=>${$nice},});

my $start = {};
my $stop = {};
#
my $indexfile ;
my $vdrversion = ${$vdrv} ;
if ( -e "$source_ts_dir/index" ) { $indexfile = "$source_ts_dir/index" }  ;
if ( -e "$source_ts_dir/index.vdr" ) { $vdrversion = '1.6'; $indexfile = "$source_ts_dir/index.vdr" }  ;

if ( not ( $indexfile ) ) {
 return ('indexfile not found in combine_ts');
}

$self->message({msg=>"combine TS Files in ${$source_ts}",}) ;
$self->message({msg=>'get Byte Positions based on marks',debug=>${$dbg},v=>'v',}) ;

my $ref_marks = \$self->parsevdrmarks({dir=>$source_ts_dir,fps=>${$fps},debug=>${$dbg},marksfile=>${$marksfile},});

$self->changexmlfile({file=>$xmlfile,action=>'add',field=>'totalframes',content=>${$ref_marks}->{'totalframes'},debug=>${$dbg},});

my $cutcount = ${$ref_marks}->{'cutcount'}-1;



foreach my $a (0 .. $cutcount) {

my $startframe = ${$ref_marks}->{"start_fps$a"};
my $stopframe = ${$ref_marks}->{"stop_fps$a"};
my ($sta,$staf) = \$self->_getoffset({frame=>$startframe,index=>$indexfile,vdrversion=>$vdrversion,debug=>${$dbg},});
my ($sto,$stof) = \$self->_getoffset({frame=>$stopframe,index=>$indexfile,vdrversion=>$vdrversion,debug=>${$dbg},});
$start->{"pos$a"} = ${$sta};
$start->{"file$a"} = ${$staf};

$stop->{"pos$a"} = ${$sto};
$stop->{"file$a"} = ${$stof};

my $t=${$ref_marks}->{"start_time$a"} ;
$self->message({msg=>"||cut -> $a time in sek -> $t || frame -> $startframe || byteposition start -> ${$sta} in File ${$staf} stop -> ${$sto} in File ${$stof}",debug=>${$dbg},v=>'vvv',}) ;
}

my $wrkfile = q{};
for my $a (0 .. $cutcount ) {
my $rc = q{};
$self->message ({msg=>"cut $a in .ts file from vdr cutlist...",debug=>${$dbg},v=>'v',}) ;

my $filea = $start->{"file$a"};
my $fileb = $stop->{"file$a"};

if ( $filea == $fileb ) {
  ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$start->{"file$a"},});
  $self->message ({msg=>"proccess ${$wrkfile} ***$filea == $fileb ",debug=>${$dbg},v=>'vvv',}) ;
  $rc = \$self->_cutfile ({sourcedir=>$source_ts_dir,
    target=>${$target_ts},
    startpos=>$start->{"pos$a"},
    stoppos=>$stop->{"pos$a"},
    file=>${$wrkfile},
    debug=>${$dbg},
  });
  $wrkfile = q{};
} elsif ( $filea != $fileb ) {
  # cutpart one
  ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$start->{"file$a"},});
  my $bytesizefile = -s ${$wrkfile};
  $self->message ({msg=>"proccess ${$wrkfile} ***$filea != $fileb ",debug=>${$dbg},v=>'vvv',}) ;
  my $rc1 = \$self->_cutfile ({sourcedir=>$source_ts_dir,
    target=>${$target_ts},
    startpos=>$start->{"pos$a"},
    stoppos=>$bytesizefile,
    file=>${$wrkfile},
    debug=>${$dbg},
 });
  $wrkfile = q{};
 # logik wenn fileb nicht die direkte folge nummer ist sprich 1 != 5 z.b
 if (${$rc1} eq '_cutfile_done') {
  if ( ( $filea + 1 ) == $fileb ) {
  # cutpart two
    ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$stop->{"file$a"},});
    $self->message ({msg=>"proccess ${$wrkfile} ***$filea+1 == $fileb ",debug=>${$dbg},v=>'vvv',}) ;
    $rc = \$self->_cutfile ({sourcedir=>$source_ts_dir,
      target=>${$target_ts},
      startpos=>'0',
      stoppos=>$stop->{"pos$a"},
      file=>${$wrkfile},
      debug=>${$dbg},
    });
   $wrkfile = q{};

  } else {
     my $filecount = $filea+1;
     my $lastmergefile = $fileb-1;
     my $tojoinfiles=q{};
      while ( $lastmergefile >= $filecount ) {
	my ($jf,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$filecount,});
	my $filename =  basename ${$jf};
	$tojoinfiles="$tojoinfiles $filename";
	$filecount++;
      }
      $self->message ({msg=>"call _joinfiles dir = $source_ts_dir files = $tojoinfiles" ,debug=>${$dbg},v=>'vvv',}) ;
      my $joinrc = \$self->_joinfiles({dir=>$source_ts_dir,files=>$tojoinfiles,});
      $self->message ({msg=>"_joinfiles return = ${$joinrc}" ,debug=>${$dbg},v=>'vvv',}) ;
      ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$fileb,});
      $rc = \$self->_cutfile ({sourcedir=>$source_ts_dir,
	target=>${$target_ts},
	startpos=>'0',
	stoppos=>$stop->{"pos$a"},
	file=>${$wrkfile},
	debug=>${$dbg},
      });
    $wrkfile = q{};
  }
}
}

if (${$rc} eq '_cutfile_done') { $a++ ; }

} # end while

return ('combine_ts_done');

}
sub _get_files_in_dir {
my ( $self,$args ) = @_;
my $dir = \$args->{'dir'};
my $p = \$args->{'pattern'};
my $pattern = q{*};
if ( ${$p} ) { $pattern = ${$p} ; }
my @files ;
foreach my $f (bsd_glob "${$dir}/$pattern") {
  push @files,$f;
}
return (@files);
}

sub _get_filename_by_cutfilenumber {
my ( $self,$args ) = @_;
my $source_dir = \$args->{'dir'};
my $fileno = \$args->{'fileno'};
my $start_ts = q{};
my $vdrversion = '1.7';
my $dbg=\$args->{'debug'};
my @filelist=\$self->_get_files_in_dir ({dir=>${$source_dir},});

foreach my $f (@filelist) {
	$self->message({msg=>"_get_filename_by_cutnumber | ${$f} ${$fileno}",v=>'vvv',debug=>${$dbg},});
  if (${$f} =~ /(${$fileno})[.]vdr$/smx ) {
    $start_ts = ${$f};
    $vdrversion = '1.6';
  }
  if (${$f} =~ /(${$fileno})[.]ts$/smx ) {
    $start_ts = ${$f};
  }

}

return ($start_ts,$vdrversion);
}

sub _cutfile {
my ($self,$args) = @_;
#return ('_cutfile_done'); # for testing enable
my $source_ts_dir = \$args->{'sourcedir'} ;
my $target = \$args->{'target'} ;
my $start = \$args->{'startpos'};
my $stop = \$args->{'stoppos'};
my $file = \$args->{'file'};
my $dbg=\$args->{'debug'};
my $buffer;
my $cont;
#


$self->message ({msg=>"cut file ${$file} ( start = ${$start} / stop = ${$stop} )",debug=>${$dbg},v=>'vvv',}) ;
#
open my $TOFH, '>>:raw', ${$target} or croak $self->message ({msg=>"cannot open ${$target} for writing ... $ERRNO",}) ;

open my $FH , '<:raw', ${$file} or croak $self->message ({msg=>"can't open ${$file} ... $ERRNO",}) ;
       seek $FH,${$start},0;
       while ($cont = read $FH, $buffer, BUFFERSIZE ) {
        my $readpos = tell $FH;
        if ($readpos == ${$stop} ) { last ; }
	if ($readpos > ${$stop} ) {
	  my $diff = $readpos - ${$stop};
	  $self->message({msg=>"cutfiles | write | bytepos $readpos stop ${$stop} diff $diff ",v=>'vvv',debug=>${$dbg},});
	  use bytes;
	  my $newbuffer = bytes::substr $buffer,0,-$diff;
	  my $newbufsize = bytes::length $newbuffer;
	  no bytes;
	  $self->message({msg=>"cutfiles | write last $newbufsize bytes",v=>'vvv',debug=>${$dbg},});
          print {$TOFH} $newbuffer or croak "can't write to ${$target} $ERRNO";
	  last ;
	} else {
	  print {$TOFH} $buffer or croak "can't write to ${$target} $ERRNO";
	}
      }
 close $FH or croak $self->message({msg=>"can´t close ${$file} $ERRNO",});
 close $TOFH or croak $self->message({msg=>"can´t close ${$target} $ERRNO",}) ;
 $self->message ({msg=>"cut file ${$file} proccessed",debug=>${$dbg},v=>'v',}) ;
return ('_cutfile_done');
}


sub _getoffset {
my ($self,$args) = @_;
my $f = \$args->{'frame'};
my $frame = ${$f}-1;
my $index = \$args->{'index'};
my $startpos = ACHT * $frame ;
#my $vdrv=\$args->{'vdrversion'};
my $platform=$Config{'archname'};
my $defaultunpack = 'issQ' ; # lssQ 64 bit perl version for vdr 1.7
my $defaultversion = $args->{'vdrversion'} || '1.7';
my $dbg=\$args->{'debug'};

#if ( $args->{'vdrversion'} ) { $defaultversion = ${$vdrv} ; }

if ($defaultversion =~ /^1[.]6$/smx ) {
  $defaultunpack = 'icci';
}
if ( ( $platform =~ /i486/smx ) and ( $defaultversion =~ /^1[.]7$/smx ) ) {
  $defaultunpack = 'iccS';
}

if ( not ( ${$index} ) ) { return ('index not found in _getoffset'); }

my ($byteoffset,$byteoffset1,$byteoffset2,$filenumber,$frametype);

my $buffer = \$self->_readindex({index=>${$index},frame=>$startpos,});


given ( $defaultunpack ) {
   when ( /^iccS$/smx ) {
      ($byteoffset,$byteoffset2,$frametype,$filenumber,undef) = unpack 'iccS' , ${$buffer}; # lssLL alt
        if ($byteoffset2 > 0 ) {
	  use bigint;
	  $byteoffset += DREIZWEI * $byteoffset2;
	}
   }
    when ( /^icci$/smx ) {
      ($byteoffset,$frametype,$filenumber,undef) = unpack 'icci' , ${$buffer};
   }
    when ( /^issQ$/smx ) {
      ($byteoffset,$frametype,$filenumber,undef) = unpack 'issQ' , ${$buffer};
   }
}

#if ( ( $platform =~ /i486/smx ) and ( $defaultversion =~ /^1[.]7$/smx ) ) {
# ($byteoffset,$byteoffset2,$frametype,$filenumber,undef) = unpack 'iccS', ${$buffer}; # lssLL alt
#
#  if ($byteoffset2 > 0 ) {
#    use bigint;
#    $byteoffset += DREIZWEI * $byteoffset2;
#  }
#} else {
#  ($byteoffset,$frametype,$filenumber,undef) = unpack 'icci' , ${$buffer};
#}

	$self->message({msg=>"offset $byteoffset",v=>'vvv',debug=>${$dbg},});
	if ( $byteoffset2 ) { $self->message({msg=>"offset2 $byteoffset2",v=>'vvv',debug=>${$dbg},}); }
	$self->message({msg=>"frametype $frametype",v=>'vvv',debug=>${$dbg},});
	$self->message({msg=>"fileno $filenumber",v=>'vvv',debug=>${$dbg},});

#my $test += 32*$byteoffset2;
#print "$test\n";


return ($byteoffset,$filenumber);
}

sub _readindex {
my ($self,$args) = @_;
my $frame = \$args->{'frame'};
my $index = \$args->{'index'};
my $buffer = q{};

open my $INDEX, '<:raw', ${$index} or croak $self->message({msg=>"Couldn't open ${$index} $ERRNO"});
  seek $INDEX, ${$frame} ,'0' ;
  read $INDEX, $buffer, ACHT;
close $INDEX or croak $self->message({msg=>"Couldn't close ${$index} $ERRNO"});

return ($buffer);
}
sub _joinfiles {
my ($self,$args) = @_;
my $dir = \$args->{'dir'};
my $dbg = \$args->{'debug'};
my $files = \$args->{'files'};
my $destinationfile = $args->{'destination'} || 'vdrtranscode.ts';

#my $destinationfile='vdrtranscode.ts';
#if (${$destfile}) {
#  $destinationfile = ${$destfile};
#}

my $buffer;
my $copied;
my $fh_out;
my @infiles;
if ( ${$files} =~ /\s/smx ) {
  @infiles = split /\s/smx , ${$files};
} else {
  push @infiles,${$files};
}

my $wrmode = '>>:raw';

if ( -e "${$dir}/$destinationfile" ) { return ('_joinfiles vdrtranscode.ts exists'); }

for my $file (@infiles) {
    if ( $file eq q{} ) { next ;};
    $self->message ({msg=>"[joinfiles]proccess ${$dir}/$file",debug=>${$dbg},v=>'vvv',});
    open $fh_out, $wrmode , "${$dir}/$destinationfile" or croak "can't open ${$dir}/$destinationfile $ERRNO";
    open my $fh_in, '<:raw', "${$dir}/$file" or croak "can't open ${$dir}/$file $ERRNO";
    while ($copied = read $fh_in, $buffer, BUFFERSIZE) {
        print {$fh_out} $buffer or croak "can't write to ${$dir}/$destinationfile $ERRNO";
    }
    close $fh_in or croak $ERRNO;
    close $fh_out or croak $ERRNO;
}
return ('joindone');
} # end sub _joinfiles

sub writefile {
my ($self,$args) = @_;
my $file = \$args->{'file'};
my $o = \$args->{'options'};
my @content = @{$args->{'content'}};
my $options = '>';
if (${$o}) {
  $options = ${$o};
}
open my $WRITE , $options , ${$file} or croak "can't open ${$file} for writefile $ERRNO";
    flock $WRITE, LOCK_EX or croak "can't lock ${$file} for writefile $ERRNO";
    foreach my $l (@content) {
      print {$WRITE} "$l\n" or croak "can't write to ${$file} for writefile $ERRNO";
    }
    flock $WRITE, LOCK_UN or croak "can't close ${$file} for writefile $ERRNO";
close $WRITE or croak $ERRNO;
return ('writedone');
}

sub readfile {
my ($self,$args) = @_;
my $file = \$args->{'file'};

my @content = ();
my $rc = { returncode=>'readfile_done' };

if ( not ( -e ${$file} ) ) { $rc->{'returncode'} = 'readfile_filenotfound'; return ($rc) }

open my $FH , '<', ${$file} or croak "can't open ${$file} for readfile $ERRNO";
  while (<$FH>) {
    chomp;
    push @content,$_;
  }
close $FH or croak $ERRNO;
$rc->{'returndata'} = \@content;

return ($rc);
}

1;
