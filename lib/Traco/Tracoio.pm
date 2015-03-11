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
no if $] >= 5.018, warnings => "experimental";
use File::Basename;
use Data::Dumper;
use File::Glob ':glob';
use Fcntl ':flock';
use Config;
use Encode;
use constant {BUFFERSIZE => 32_768, ACHT => 8, DREIZWEI => 32, DREI => 3};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);
@EXPORT_OK = qw(combine_ts readfile writefile getfilelist _cutfile _getfps);

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
#
my @dirlist ;
#

sub getfilelist {
my ($self,$args) = @_;
my $searchpath = \$args->{'dir'};
my $debug = \$args->{'debug'};
my $p = \$args->{'pattern'};
my $skiplinks = \$args->{'skiplinks'};
my $pattern = '(?:(?:[.](?:ts|vdr|xml|lck))|info|index|marks|resume)';
my $fs = \$args->{'fs'};


if ( ${$p} ) {
  $pattern = ${$p} ;
}

my @CA = caller 1;

if ( ($CA[DREI] ) and ( $CA[DREI] ne 'Traco::Tracoio::getfilelist') ) {
  $self->message({ msg=>'Tracoio.pm|getfilelist',v=>'vvvvv',});
  @dirlist = ();
}

$self->message({ msg=>"Tracoio.pm|getfilelist|search pattern = $pattern",debug=>${$debug},v=>'vvvvv',});

if ( not ( -d ${$searchpath} ) ) { return ('getfilelist_pathnotfound'); }
$self->message({ msg=>"Tracoio.pm|getfilelist|searchpath ${$searchpath} exist",debug=>${$debug},v=>'vvvvv',});

#my @double = grep { /\Q(${$searchpath})/smx } @dirlist ;
#if ( $#double >= 0 ) { next  ;};
#undef @double;

my $flist = _get_files_in_dir({dir=>${$searchpath},debug=>${$debug},});


for ( @ { $flist } ) {
  my $file  = $_;
  my $dir = dirname $file;
  if ( $file =~ /($pattern)/smx ) { next ; }
  if ( -d $file ) {
    $self->getfilelist ({dir=>$file,pattern=>$pattern,skiplinks=>${$skiplinks},debug=>${$debug},fs => ${$fs} , v=>'vvvvv',}) ;
  }

  # skip directory are marked as delete by vdr
  # or lck files
  if ( $file =~ /[.]del$/smx ) { next ; }
  # skip links if option set
  if ( ( ${$fs} !~ /^cifs$/smx ) and ( ${$skiplinks} ) and ( -l $file ) ) { next ; }
  # skip double entrys
  if ( grep { /$file/smx } @dirlist ) { next ; }

  if ( -e $file ){
        push @dirlist,$file;
  }
};

undef @CA;
undef $flist;

return (@dirlist);
} # end sub

sub _getfps {
my ($self,$args) = @_;
my $fpstype = \$args->{'fpstype'};
my $dbg=\$args->{'debug'};
my $dir=\$args->{'dir'};
my $returnline;
my $hb=\$args->{'handbrake'};
my $nice=\$args->{'nice'};
my $xml = \$args->{'xml'};

#my @CA = caller 1;
#print Dumper $CA[3];
#print Dumper $args;
#######
     # um die richtige fps zahl zu haben fuer die berechnung
     given ( ${$fpstype} ) {
      when ( /^vdr$/smx ) {
	my $vdrfps = \$self->getfromxml({file=>"${$dir}/${$xml}",
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
my $xml = \$args->{'xml'};
my $xmlfile = ${$xml};
my $idxfile = \$args->{'indexfile'};

if ( -e "${$source_ts}/${$target_ts}" ) { return ("[combine_ts]target_ts exist ${$source_ts}/${$target_ts}") };
if ( not ( ${$vdrv} ) ) { return ('[combine_ts]missing_vdrversion_option'); };
if ( not ( ${$idxfile} ) ) { return ('[combine_ts]missing_indexfile_option'); };

my $fps=\$self->_getfps({fpstype=>${$fpstype},dir=>${$source_ts},debug=>${$dbg},handbrake=>${$hb},nice=>${$nice},xml=>${$xml},});
$self->message({msg=>"[combine_ts]got ${$fps} from _getfps",debug=>${$dbg},}) ;

my $start = {};
my $stop = {};
#
my $vdrversion = ${$vdrv} ;
my $indexfile = "${$source_ts}/${$idxfile}";

#if ( $indexfile eq 'missing' ) {
# return ('combine_ts: indexfile not found');
#}

$self->message({msg=>"[combine_ts]TS Files in ${$source_ts}",}) ;
$self->message({msg=>'[combine_ts]get Byte Positions based on marks',debug=>${$dbg},v=>'v',}) ;

my $ref_marks = \$self->parsevdrmarks({dir=>$source_ts_dir,fps=>${$fps},debug=>${$dbg},marksfile=>${$marksfile},});


my $cutcount = ${$ref_marks}->{'cutcount'}-1;


foreach my $cp (0 .. $cutcount) {

my $startframe = ${$ref_marks}->{"start_fps$cp"};
my $stopframe = ${$ref_marks}->{"stop_fps$cp"};
my ($sta,$staf) = \$self->_getoffset({frame=>$startframe,index=>$indexfile,vdrversion=>$vdrversion,debug=>${$dbg},});
my ($sto,$stof) = \$self->_getoffset({frame=>$stopframe,index=>$indexfile,vdrversion=>$vdrversion,debug=>${$dbg},});
$start->{"pos$cp"} = ${$sta};
$start->{"file$cp"} = ${$staf};

$stop->{"pos$cp"} = ${$sto};
$stop->{"file$cp"} = ${$stof};

my $t=${$ref_marks}->{"start_time$cp"} ;
$self->message({msg=>"[combine_ts]cut -> $cp time in sek -> $t || frame -> $startframe || byteposition start -> ${$sta} in File ${$staf} stop -> ${$sto} in File ${$stof}",debug=>${$dbg},}) ;
}

my $wrkfile = q{};
for my $a (0 .. $cutcount ) {
my $rc = q{};

my $filea = $start->{"file$a"};
my $startfile = $start->{"file$a"};


my $fileb = $stop->{"file$a"};


if ( $startfile == $fileb ) {
  ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$startfile,});
  
  $self->message ({msg=>"[combine_ts]proccess ${$wrkfile} ***$startfile == $fileb ",debug=>${$dbg},v=>'vvv',}) ;
  $rc = \$self->_cutfile ({dir=>$source_ts_dir,
    target=>${$target_ts},
    startpos=>$start->{"pos$a"},
    stoppos=>$stop->{"pos$a"},
    file=>${$wrkfile},
    debug=>${$dbg},
  });
  $wrkfile = q{};
} elsif ( $filea != $fileb ) {
  # cutpart one
  
  ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$startfile,});
  $self->message ({msg=>"[combine_ts]proccess ${$wrkfile} ***$ startfile != $fileb ",debug=>${$dbg},}) ;
 
  my $bytesizefile = -s ${$wrkfile};
  my $rc1 = \$self->_cutfile ({dir=>$source_ts_dir,
    target=>${$target_ts},
    startpos=>$start->{"pos$a"},
    stoppos=>$bytesizefile,
    file=>${$wrkfile},
    debug=>${$dbg},
 });
  $wrkfile = q{};
 # logic wenn fileb nicht die direkte folgen nummer ist sprich 1 != 5 z.b
 if (${$rc1} eq '_cutfile_done') {
 
  if ( ( $filea + 1 ) == $fileb ) {
  # cutpart two
    ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$stop->{"file$a"},});
    $self->message ({msg=>"[combine_ts]proccess ${$wrkfile} ***$filea+1 == $fileb ",debug=>${$dbg},}) ;
    $rc = \$self->_cutfile ({dir=>$source_ts_dir,
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
	$tojoinfiles .= " $filename";
	$tojoinfiles =~ s/^\s//smx ;
	
	#print Dumper $tojoinfiles;
	$filecount++;
      }
      $self->message ({msg=>"[combine_ts]call _joinfiles dir = $source_ts_dir files = $tojoinfiles" ,debug=>${$dbg},}) ;
      my $joinrc = \$self->_joinfiles({dir=>$source_ts_dir,files=>$tojoinfiles,destination=>${$target_ts},debug=>${$dbg},});
      $self->message ({msg=>"[combine_ts]_joinfiles call return = ${$joinrc}" ,debug=>${$dbg},}) ;
      ($wrkfile,undef) = \$self->_get_filename_by_cutfilenumber({dir=>$source_ts_dir,fileno=>$fileb,});
      $rc = \$self->_cutfile ({dir=>$source_ts_dir,
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

return ('combine_ts_done')
}
sub _get_files_in_dir {
my $args = shift;
my $dir = \$args->{'dir'};
my $p = \$args->{'pattern'};
my $pattern = q{*};
if ( ${$p} ) { $pattern = ${$p} ; }
my @files ;

foreach my $f (bsd_glob "${$dir}/$pattern") {
  push @files,$f;
}


return \@files;
}

sub _get_filename_by_cutfilenumber {
my ( $self,$args ) = @_;
my $source_dir = \$args->{'dir'};
my $fileno = \$args->{'fileno'};
my $start_ts = q{};
my $vdrversion = '1.7';
my @filelist=\$self->_get_files_in_dir ({dir=>${$source_dir},});


my $vdrfile = sprintf '%05d', ${$fileno};


map {
	if (${$_} =~ /($vdrfile)[.]vdr$/smx ) {
   	$start_ts = ${$_};
		$vdrversion = '1.6';
	}
	if (${$_} =~ /($vdrfile)[.]ts$/smx ) {
   	$start_ts = ${$_};
	}
} @filelist;

return ($start_ts,$vdrversion);
}

sub _cutfile {
my ($self,$args) = @_;
#print Dumper $args;
my $dir = \$args->{'dir'} ;
my $target = \$args->{'target'} ;
my $start = \$args->{'startpos'};
my $stop = \$args->{'stoppos'};
my $file = \$args->{'file'};
my $dbg=\$args->{'debug'};
my $buffer;
my $cont;
#
my $writetype='>:raw';

if ( -e "${$dir}/${$target}" ) { $writetype='>>:raw'; }
 
$self->message ({msg=>"[_cutfile]cut in ${$dir} file ${$file} ( start = ${$start} / stop = ${$stop} )",debug=>${$dbg},}) ;
#
open my $TOFH, $writetype , "${$dir}/${$target}" or carp $self->message ({msg=>"[_cutfile] cannot open ${$dir}/${$target} for writing ... $ERRNO",}) ;

open my $FH , '<:raw', ${$file} or carp $self->message ({msg=>"[_cutfile] can't open ${$file} ... $ERRNO",}) ;
       seek $FH,${$start},0;
       while ($cont = read $FH, $buffer, BUFFERSIZE ) {
        my $readpos = tell $FH;
        if ($readpos == ${$stop} ) { last ; }
	if ($readpos > ${$stop} ) {
	  my $diff = $readpos - ${$stop};
	  $self->message({msg=>"[_cutfile]write | bytepos $readpos stop ${$stop} diff $diff ",debug=>${$dbg},});
	  use bytes;
	  my $newbuffer = bytes::substr $buffer,0,-$diff;
	  my $newbufsize = bytes::length $newbuffer;
	  no bytes;
	  $self->message({msg=>"[_cutfile]write last $newbufsize bytes",debug=>${$dbg},});
          print {$TOFH} $newbuffer or carp "[_cutfile]can't write to ${$dir}/${$target} $ERRNO";
	  last ;
	} else {
	  print {$TOFH} $buffer or carp "[_cutfile]can't write to ${$dir}/${$target} $ERRNO";
	}
      }
 close $FH or carp $self->message({msg=>"[_cutfile]can´t close ${$file} $ERRNO",});
 close $TOFH or carp $self->message({msg=>"[_cutfile]can´t close ${$dir}/${$target} $ERRNO",}) ;
 $self->message ({msg=>"[_cutfile]cut file ${$file} proccessed",debug=>${$dbg},}) ;
return ('_cutfile_done');
}


sub _getoffset {
my ($self,$args) = @_;
my $f = \$args->{'frame'};
my $dbg = \$args->{'debug'};
my $frame = ${$f}-1;
my $index = \$args->{'index'};
my $startpos = ACHT * $frame ;
my $vdrv=\$args->{'vdrversion'};
my $platform=$Config{'archname'};
my $defaultunpack = 'issQ' ; # lssQ 64 bit perl version for vdr 1.7
my $defaultversion = '1.7';
if ( ${$vdrv} ) { $defaultversion = ${$vdrv} ; }

if ($defaultversion =~ /^1[.]6$/smx ) {
  $defaultunpack = 'icci';
}

if ( not ( ${$index} ) ) { return ('index not found in _getoffset'); }

my ($byteoffset,$byteoffset2,$filenumber,$frametype);

my $buffer = \$self->_readindex({index=>${$index},frame=>$startpos,});


if ( ( $platform =~ /i486/smx ) and ( $defaultversion =~ /^1[.]7$/smx ) ) {
 ($byteoffset,$byteoffset2,$frametype,$filenumber,undef) = unpack 'iccS', ${$buffer}; # lssLL alt
  if ($byteoffset2 > 0 ) {
    use bigint;
    $byteoffset += DREIZWEI * $byteoffset2;
  }

} else {
  ($byteoffset,$frametype,$filenumber,undef) = unpack $defaultunpack, ${$buffer};
}

 if ( ${$dbg} ) {
		print "offset $byteoffset\n";
		print "frametype $frametype\n"; 
		print "fileno $filenumber\n";
}


return ($byteoffset,$filenumber);
}

sub _readindex {
my ($self,$args) = @_;
my $frame = \$args->{'frame'};
my $index = \$args->{'index'};
my $buffer = q{};

open my $INDEX, '<:raw', ${$index} or carp $self->message({msg=>"Couldn't open ${$index} $ERRNO"});
  seek $INDEX, ${$frame} ,'0' ;
  read $INDEX, $buffer, ACHT;
close $INDEX or carp $self->message({msg=>"Couldn't close ${$index} $ERRNO"});

return ($buffer);
}
sub _joinfiles {
my ($self,$args) = @_;
#print Dumper $args;
my $dir = \$args->{'dir'};
my $dbg = \$args->{'debug'};
my $files = \$args->{'files'};
my $destfile = \$args->{'destination'};

if ( ! $args->{'destination'} ) { return '_joinfiles missing destination'};


my $buffer;
my $copied;
my $fh_out;
my @infiles;
if ( ${$files} =~ /\s/smx ) {
  @infiles = split /\s/smx , ${$files};
} else {
  push @infiles,${$files};
}

my $opentype = '>:raw';

	

for ( @infiles ) {
#	print Dumper $_;
   if ( $_ eq q{} ) { next ;};
	if ( -e "${$dir}/${$destfile}" ) { $opentype = '>>:raw' ; }
    $self->message ({msg=>"[joinfiles]proccess ${$dir}/$_",debug=>${$dbg},});
    open $fh_out, $opentype , "${$dir}/${$destfile}" or carp "[_JOINFILES]can't open destination ${$dir}/${$destfile} $ERRNO";
    open my $fh_in, '<:raw', "${$dir}/$_" or carp "[_JOINFILES]can't open ${$dir}/$_ $ERRNO";
    while ($copied = read $fh_in, $buffer, BUFFERSIZE) {
        print {$fh_out} $buffer or carp "[_JOINFILES]can't write to ${$dir}/${$destfile} $ERRNO";
    }
    close $fh_in or carp $ERRNO;
    close $fh_out or carp $ERRNO;
};



return ('joindone');
} # end sub _joinfiles

sub writefile {
my ($self,$args) = @_;
my @CA = caller 1;
my $file = \$args->{'file'};
my $o = \$args->{'options'};
my @content = @{$args->{'content'}};
my $options = '>';
if (${$o}) {
  $options = ${$o};
}
open my $WRITE , $options , ${$file} or carp "can't open ${$file} for writefile $ERRNO";
    flock $WRITE, LOCK_EX or carp "can't lock ${$file} for writefile $ERRNO";
    
    map {
    	if ( $CA[DREI] !~ /writelog$/smx ) {
      	print {$WRITE} "$_\n" or carp "can't write to ${$file} for writefile $ERRNO";
      } else {
        	print {$WRITE} $_ or carp "can't write to ${$file} for writefile $ERRNO";
      }
    } @content;
    
    
#    foreach my $l (@content) {
#    	if ( $CA[DREI] !~ /writelog$/smx ) {
#      	print {$WRITE} "$l\n" or carp "can't write to ${$file} for writefile $ERRNO";
#      } else {
#        	print {$WRITE} $l or carp "can't write to ${$file} for writefile $ERRNO";
#      }
#    }
    
    
    flock $WRITE, LOCK_UN or carp "can't close ${$file} for writefile $ERRNO";
close $WRITE or carp $ERRNO;
return ('writedone');
}

sub readfile {
my ($self,$args) = @_;
my $file = \$args->{'file'};

#print Dumper $args;

#my @CA = caller 1;
#print Dumper $CA[3];
#print Dumper $args;
my @content = ();
my $rc = { returncode=>'readfile_done' };

if ( not ( -e ${$file} ) ) { $rc->{'returncode'} = 'readfile_filenotfound'; return ($rc) }

open my $FH , '<', ${$file} or carp "can't open ${$file} for readfile $ERRNO";
  while (<$FH>) {
    chomp;
    push @content,$_;
  }
close $FH or carp $ERRNO;
$rc->{'returndata'} = \@content;

return ($rc);
}

1;
