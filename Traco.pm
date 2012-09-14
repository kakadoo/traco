package Traco::Traco;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Traco.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#
use Traco::Tracoio ;
use Traco::Tracoxml ;
use Traco::Tracoprofile ;
use Traco::Tracorenamefile ;
use Traco::Tracovdr;
use Traco::Tracohandbrake;

#
use English '-no_match_vars';
use Carp;

use IPC::Open3 'open3';
use feature qw/switch/;
use Sys::Hostname;
use File::Basename;
#use Data::Dumper;
use Fcntl ':flock';
use Sys::Syslog qw/:DEFAULT setlogsock/;
use constant { EINSNULLNULLNULL => 1000,
		DREI => 3,
		FUENF => 5,
		ACHT => 8,
		EINSNULLZWEIVIER => 1024,
		DREISECHSNULLNULL => 3600,
		ZWEINULL => 20,
		ZWEIFUENF => 25,
		FUENFNULL => 50,
		SECHSNULL => 60,
		EINSNULLNULL => 100,
		VIERNULLNULLNULL => 4000,
		SECHSNULLNULL => 600,
		EMPIRIC_FACTOR => 1.018,
		NEUNZEHNNULLNULL => 1900,};

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter Traco::Tracoio Traco::Tracoxml Traco::Tracoprofile Traco::Tracorenamefile Traco::Tracovdr Traco::Tracohandbrake);

#@EXPORT_OK = qw(prepare_traco_ts chkvdrversion recalculate_video_bitrate setup parsevdrmarks parsevdrinfo findmyfile _filelist removelockfile writelockfile readlockfile _runexternal parseconfig preparepath message setcpuoptions run_handbrake prepare_crop buildrunline _handbrakeanalyse_cas _parse_config_value);
@EXPORT_OK = qw(prepare_traco_ts recalculate_video_bitrate setup findmyfile _filelist removelockfile writelockfile readlockfile _runexternal parseconfig preparepath message setcpuoptions prepare_crop buildrunline _ _parse_config_value);

$VERSION = '0.22';

#
# 0.01 inital version
# 0.21 add _parse_config_value
# 0.22 split sub to Tracovdr and Tracohandbrake
#      remove Find::File subs
#

sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	my $d = \$args->{'debug'} ;
	$self->{'debug'} = ${$d};
	$self->{'facility'} = 'syslog';
	$self->{'priority'} = 'info';
	if (${$d}) { print {*STDOUT} "$PROGRAM_NAME | new | uid = $UID | debug = ${$d}\n" or croak $ERRNO; }
	bless $self,$class;
	return $self;
} # end sub new
my @dirlist = ();


sub prepare_traco_ts {
my ($self,$args) = @_;
my $dir = \$args->{'source'};
my $dbg = \$args->{'debug'};
my $vdrversion=\$args->{'vdrversion'},
my $fpstype=\$args->{'fpstype'},
my $hb_bin=\$args->{'hb_bin'},
my $nice= \$args->{'nice'},
my $xmlfile = "${$dir}/vdrtranscode.xml";
my $returncode = 'prepare_traco_ts_done';

my $vdr_marks = q{};
my $vdr_info = q{};

if ( -e "${$dir}/marks" ) { $vdr_marks="${$dir}/marks";}
if ( -e "${$dir}/marks.vdr" ) { $vdr_marks="${$dir}/marks.vdr";}
if ( -e "${$dir}/info" ) { $vdr_info="${$dir}/info";}
if ( -e "${$dir}/info.vdr" ) { $vdr_info="${$dir}/info.vdr";}

if ($vdr_marks eq q{} ) {
my $files = \$self->getfromxml({file=>$xmlfile,field=>'files',debug=>${$dbg},});
my $info = \$self->parsevdrinfo({dir=>${$dir},file=>$vdr_info,debug=>${$dbg},});
my $totalframes = ${$info}->{'duration'} * ${$info}->{'frames'};

  if ( ( defined ${$files} ) and ( ${$files} ne q{} ) ) {
    my $rc=\$self->_joinfiles({dir=>${$dir},files=>${$files},debug=>${$dbg},});
    if (${$rc} eq 'joindone') {
      $self->changexmlfile({file=>$xmlfile,action=>'change',field=>'status',to=>'online',debug=>${$dbg},});
      $self->changexmlfile({file=>$xmlfile,action=>'add',field=>'totalframes',content=>$totalframes,debug=>${$dbg},});
    }
    undef $files;
  } else {
    $returncode = 'prepare_traco_ts_join_error';
  }
} else {
      my $cutrc=\$self->combine_ts ({source=>${$dir},
					      target=>"${$dir}/vdrtranscode.ts",
					      debug=>${$dbg},
					      vdrversion=>${$vdrversion},
					      fpstype=>${$fpstype},
					      handbrake=>${$hb_bin},
					      nice=>${$nice},
					      marksfile=>$vdr_marks,
					      });
	if ( ${$cutrc} eq 'combine_ts_done' ) {
	  $self->changexmlfile({file=>$xmlfile,action=>'change',field=>'status',to=>'online',debug=>${$dbg},});
	} else {
	  $self->message ({msg=>"prepare_traco_ts returncode ${$cutrc} in $dir",v=>'vvv'});
	  $returncode = 'prepare_traco_ts_cut_error';
	}
      $cutrc=q{};
}

return ($returncode);
}


sub setup {
my ($self,$args) = @_;
my $fac = \$args->{'facility'};
my $pri = \$args->{'priority'};
my $ll = \$args->{'daemon'};
my $vl = \$args->{'verboselevel'};

if (${$fac}) {
  $self->{'facility'} = ${$fac};
}
if (${$pri}) {
  $self->{'priority'} = ${$pri};
}
if (${$ll}) {
  $self->{'daemon'} = ${$ll} ;
}
if (${$vl}) {
  $self->{'verboselevel'} = ${$vl} ;
}

return ();
}

sub _preparedtime {
my ($self,$args) = @_;
my $tif = \$args->{'timeformat'};
my $ti =q{};
my $tiformat = ${$tif} || '0';
my $dbg = \$self->{'debug'}  ;

my ($sec,$min,$hour,$mday,$mon,$jahr,$wday) = localtime ;
my $year=NEUNZEHNNULLNULL+$jahr;
my $mo = $mon+1 ;
given ($tiformat) {
  when ( /^1$/smx ) {
    $ti = "$hour$min$mday$mo$year";
  }
  when ( /^0$/smx ) {
    $ti = "$hour:$min:$sec $mday.$mo.$year";
  }
  when ( /^2$/smx ) {
    $ti = "$mday$mo$year";
  }
  when ( /^3$/smx ) {
    $ti = "$mday $mo $year $hour $min $sec";
  }
}
  return ($ti);
} # end sub preparetime

sub getfilelist {
my ($self,$args) = @_;
my $searchpath = \$args->{'dir'};
my $debug = \$args->{'debug'};
my $p = \$args->{'pattern'};
my $skiplinks = \$args->{'skiplinks'};
my $pattern = '(?:(?:[.](?:ts|vdr|xml|lck))|info|index|marks|resume)';

if ( ${$p} ) {
  $pattern = ${$p} ;
}

my @CA = caller 1;

if ( ($CA[DREI] ) and ( $CA[DREI] ne 'Traco::Traco::getfilelist') ) {
  $self->message({ msg=>'Vdrtranscode.pm|getfilelist',v=>'vvvvv',});
  @dirlist = ();
}

$self->message({ msg=>"Vdrtranscode.pm|_getfilelist|search pattern = $pattern",debug=>${$debug},v=>'vvvvv',});

if ( not ( -d ${$searchpath} ) ) { return ('getfilelist_pathnotfound'); }
$self->message({ msg=>"Vdrtranscode.pm|getfilelist|searchpath ${$searchpath} exist",debug=>${$debug},v=>'vvvvv',});

my @double = grep { /\Q(${$searchpath})/smx } @dirlist ;
if ( $#double >= 0 ) { next  ;};
undef @double;

my @flist =\$self->_get_files_in_dir({dir=>${$searchpath},debug=>${$debug},});



foreach my $f (@flist) {
  my $file  = ${$f};
  my $dir = dirname $file;
  # skip directory are marked as delete by vdr
  if ( $file =~ /[.]del$/smx ) { next ; }
  # skip links if option set
  if ( ${$skiplinks} ) { if ( -l $file ) { next ; } }
  if (-d $file ) {
    $self->getfilelist ({dir=>$file,pattern=>$pattern,skiplinks=>${$skiplinks},debug=>${$debug},v=>'vvvvv',}) ;
  }
  # skip double entrys
  my @tmp = grep { /\Q$dir/smx } @dirlist;

  if ( ( $#tmp < 0 ) and ( $file =~ /($pattern)/smx ) ) {
    $self->message({ msg=>"Vdrtranscode.pm|_getfilelist|add file $file to return hash \@dirlist",debug=>${$debug},v=>'vvvvv',});
    push @dirlist,$file;
  } else {
    next;
  }
  undef @tmp;
}
undef @CA;
undef @flist;

return (@dirlist);
} # end sub

sub writelockfile  {
my ($self,$args) = @_;
my $lckpath = \$args->{'dir'};
my $computer = hostname ;
my $lockfile = "${$lckpath}/vdrtranscode.lck";
my $returnline = 'done';
my @content = ();
push @content,$computer;

if ( not ( -e $lockfile ) ) {
  my $wrrc = \$self->writefile({file=>$lockfile,content=>\@content,});
} else {
  $returnline = 'file already locked';
}
undef @content;
return ($returnline);
}

sub readlockfile {
my ($self,$args) = @_;
my $lckpath = \$args->{'dir'};
my $computer = q{};

open my $FH , '<', "${$lckpath}/vdrtranscode.lck" or croak $ERRNO;
  while (<$FH>) {
    chomp;
    $computer = $_;
  }
close $FH or croak $ERRNO;

return ($computer);
}

sub removelockfile {
my ($self,$args) = @_;
my $lckpath = \$args->{'dir'};
my $rc = q{};

if (-e "${$lckpath}/vdrtranscode.lck" ) {
  $rc = unlink "${$lckpath}/vdrtranscode.lck" ;
}
return ($rc);
}



sub buildrunline {
my ($self,$args) = @_;
my $dir=\$args->{'dir'};
my $dbg=\$args->{'debug'};
my $tracoenv=\$args->{'tracoenv'};
my $hba=\$args->{'hba'};
my $profile=\$args->{'profile'};
my $recalc_video_bitrate = \$args->{'recalc_video_bitrate'};
my $target_mbyte_size = \$args->{'target_mbyte_size'};
my $useclassic = \$args->{'useclassic'};

my $runline = "nice -n ${$profile}->{'nice'} ${$profile}->{'hb_bin'} --no-dvdnav";

if ( ${$profile}->{'setcpu'} ) {
  $runline .= " -C ${$profile}->{'setcpu'}";
}

$runline .= " -i ${$dir}/vdrtranscode.ts";

if ( ${$profile}->{'largefile'} ) {
  $runline .= " --large-file";
}

if ( ${$profile}->{'quality'} !~ /^(?:rf|RF)[:]\d{1,2}$/smx ) {
  # large file bug // mp4 file over 4 Gbyte Size need "--large-file"
  if ( ( ${$target_mbyte_size} >= VIERNULLNULLNULL ) and ( ${$profile}->{'container'} =~ /(?:mp4|m4v)/smx ) ) {
    $runline .= ' --large-file';
  }
  if ( ${$recalc_video_bitrate} ) {
    $runline .= " -b ${$recalc_video_bitrate}";
  }
} else {
  my (undef,$crf) = split /[:]/smx , ${$profile}->{'quality'};
  $runline .= " -q $crf";
}

if ( ${$profile}->{'container'} =~ /^(?:mp4|m4v)$/smx ) {
  $runline .= ' -O';
}

if ( ( ${$hba}->{'audioopts'}->{'ac3tracks'} > 0 ) and ( ${$profile}->{'container'} =~ /^mp4$/smx ) ) {
  ${$profile}->{'container'} = 'm4v';
}

if ( ${$profile}->{'crop'} ) { $runline .= " --crop ${$profile}->{'crop'}" ; }
# test to prevent jerky playing on 25 fps sources
if ( ${$hba}->{'fps'} == ZWEIFUENF ) { $runline .= " -r ${$hba}->{'fps'}"; };


if ( not ( ${$useclassic} ) ) {
 if ( ${$profile}->{'codec'} ) {
   $runline .= " ${$profile}->{'codec'}";
 }
 if ( ${$profile}->{'codecopts'} ) {
   $runline .= " ${$profile}->{'codecopts'}";
 }
}

$runline .= ' -5';
if ( ${$hba}->{'audioopts'}->{'audiotracks'} ) {
 $runline .= " -a ${$hba}->{'audioopts'}->{'audiotracks'}"; #${$tracoenv}->{'audiotracks'}";
} elsif ( ${$hba}->{'audiotracks'} ) {
 $runline .= " -a ${$hba}->{'audiotracks'}"; #${$tracoenv}->{'audiotracks'}";
}
$runline .= " -A ${$hba}->{'audioopts'}->{'lang'} -E ${$hba}->{'audioopts'}->{'audioencoder'}"; #${$tracoenv}->{'lang'} -E ${$tracoenv}->{'audioencoder'}" ;
$runline .= " -B ${$hba}->{'audioopts'}->{'audiobitrate'} -D ${$hba}->{'audioopts'}->{'audionormalizer'}"; #${$tracoenv}->{'audiobitrate'} -D ${$tracoenv}->{'audionormalizer'}";
if ( ${$profile}->{'param_anamorph'} ) {
  $runline .= " ${$profile}->{'param_anamorph'}";
}
$runline .= " --modulus ${$profile}->{'modulus'}";
$runline .= " -X ${$profile}->{'param_x'}";
$runline .= " -o ${$dir}/vdrtranscode_tmp.${$profile}->{'container'}";
$runline .= ' 2>&1';

undef $profile;
undef $hba;

$self->message({msg=>"[buildrunline]runline = $runline",v=>'vvv',debug=>${$dbg},}) ;
return ($runline);
}

sub setcpuoptions {
my ($self,$args) = @_;
my $debug = \$args->{'debug'};
my $setconfig = \$args->{'config'};
my $maxconfig = \$args->{'maxcpu'};
my $cpucount = 0;
my $returnline = 1;
my $cpuinfo = \$self->_runexternal({line=>'/bin/cat /proc/cpuinfo',debug=>${$debug}});


for my $c (@{${$cpuinfo}->{'returndata'}} ) {
 if ( $c =~ /^processor(?:\s+|\t+)[:]/smx ) { $cpucount++; };
}
# if just one cpu exist
if ( $cpucount == 1 ) { return ($returnline); }

# if option maxcpu not exist
if ( not ( ${$maxconfig} ) ) { $cpucount-- ; $returnline = $cpucount; }

# if maxcpu more then real existing cpus
if ((${$maxconfig}) and (${$maxconfig} > $cpucount )) { return () };

given (${$setconfig}) {
  when ( /^auto$/smx ) {
    # use just max cpu -1;
    $cpucount--;
    $returnline = $cpucount;
  }
  when ( /^manual$/smx ) {
    if (${$maxconfig}) {
      $returnline = ${$maxconfig};
    }
  }
} # end given setconfig
return ($returnline);
}

sub message {
my ($self,$args) = @_;
my $message = \$args->{'msg'};
my $dbg=\$args->{'debug'};
my $v = \$args->{'v'} ;
#
my $isdaemon = \$self->{'daemon'};
my $verboselevel = \$self->{'verboselevel'};
my $facility = \$self->{'facility'};
my $priority = \$self->{'priority'};
#
my $vv = 0;
my $isd = 0 ;
my $vl = 0 ;
chomp ${$message} ;

if (${$isdaemon}) { $isd = 1; }
if ( ${$verboselevel} ) {$vl = length ${$verboselevel} ; }
if ( ${$v} )  { $vv = length ${$v} ; }

if ($isd == 1) {
  $self->_output_syslog({vv=>$vv,vl=>$vl,message=>${$message},debug=>${$dbg},});
} elsif ($isd == 0 ) {
  $self->_output_stdout({vv=>$vv,vl=>$vl,message=>${$message},debug=>${$dbg},});
}
undef $vv;
undef $isd;
undef $vl;
undef $message;
return ();
}

sub _output_stdout {
my ($self,$args) = @_;
my $vv = \$args->{'vv'};
my $verbose = ${$vv};
my $vl = \$args->{'vl'};
my $message = \$args->{'message'};
my $dbg = \$args->{'debug'};

  given ($verbose) {
    # daemon aus
    when ( $verbose > 0  && ${$vl} >= $verbose ) {
      print {*STDOUT} "[DEBUG]${$message}\n" or croak $ERRNO;
    }
    when ( $verbose == 0 && ${$vl} >= $verbose ) {
      print {*STDOUT} "${$message}\n" or croak $ERRNO;
    }
    when ( $verbose < ${$vl} && ${$dbg} ) {
      print {*STDOUT} "[DEBUG]${$message}\n" or croak $ERRNO;
    }
  }
undef $message;
return ();
}

sub _output_syslog {
my ($self,$args) = @_;
my $vv = \$args->{'vv'};
my $vl = \$args->{'vl'};
my $verbose = ${$vv};
my $message = \$args->{'message'};
my $facility = \$self->{'facility'};
my $priority = \$self->{'priority'};
my $dbg = \$args->{'debug'};

  given ($verbose) {
    # daemon an
    when ( $verbose == 0 && ${$vl} >= $verbose ) {
      openlog($PROGRAM_NAME,'pid,cons', ${$facility}) or croak $ERRNO;
      syslog(${$priority},"${$message}\n" ) or croak "logging failed! $ERRNO\n"  ; # debug aus
      closelog ;
    }
    when ( $verbose > 0  && ${$vl} >= $verbose ) {
      openlog($PROGRAM_NAME,'pid,cons', ${$facility}) or croak $ERRNO;
      syslog(${$priority},"[DEBUG]${$message}\n" ) or croak "logging failed! $ERRNO\n"  ; # debug aus verbose an
      closelog ;
    }
    when ( ${$vl} < $verbose && ${$dbg} ) {
      openlog($PROGRAM_NAME,'pid,cons', ${$facility}) or croak $ERRNO;
      syslog(${$priority},"[DEBUG]${$message}\n" ) or croak "logging failed! $ERRNO\n"  ; # debug aus verbose an
      closelog ;
    }
  }
undef $message;
return ();
}
sub _writelog {
my  ($self,$args) = @_;
my $line = \$args->{'line'};
my $file = \$args->{'file'};
	my @tmp;
	push @tmp,${$line};
	my $logrc = \$self->writefile({file=>${$file},content=>\@tmp,options=>'>>',});
	undef @tmp;
return ();
}
sub _runexternal {
my ($self,$args) = @_;
my $dbg = \$args->{'debug'}  ;
my $l=\$args->{'line'} ;
my $wlog=\$args->{'writelog'};

my $line = ${$l} ;
$self->message({msg=>"[_runexternal]run | $line",v=>'vvv',debug=>${$dbg},});

if ( not ( $line ) ) { return ('no_exec_line_exists_for_runexternal')};
my $returnline = {};

my @response = ();
my @errors = ();
my $childpid = open3(\*CHLD_IN,\*CHLD_OUT, \*CHLD_ERR, $line);

  use Symbol 'gensym'; #$err = gensym;
  if ( ${$dbg} ) {
    while (<CHLD_OUT>) {
      $self->message({msg=>"[_runexternal]$_",debug=>${$dbg},v=>'vvvvvvv',});
      if ( ${$wlog} ) {
	$self->_writelog({line=>$_,file=>${$wlog},});
      };
      push @response,$_;
    }
  } else {
    while (<CHLD_OUT>) {
      if ( ${$wlog} ) {
	$self->_writelog({line=>$_,file=>${$wlog},});
      };
      push @response,$_;
    }
   }
  #@response = <CHLD_OUT>;
  @errors = <CHLD_ERR>;
  waitpid $childpid,0 or croak $ERRNO;
  $returnline->{'exitcode'} = $CHILD_ERROR >> ACHT;
  chomp @errors;
  chomp @response;
  $returnline->{'returndata'} = \@response;
  $returnline->{'returnerrors'} = \@errors;

  close CHLD_OUT or croak $ERRNO;
  close CHLD_ERR or croak $ERRNO;
return ($returnline);
} # end sub _runexternal

sub parseconfig {
my ($self,$args) = @_;
my $file = \$args->{'config'};
my $debug = \$args->{'debug'};
my $config = {};
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
    my $value = \$self->_parse_config_value({value=>$tmp_value,debug=>${$debug},});
    undef $tmp_value;
    if ( ${$debug} ) { print {*STDOUT} "[DEBUG] _parseconfig | $_\n" or croak $ERRNO; }
    $config->{$key} = ${$value};
  }
  undef $lines;
return $config;
}

sub _parse_config_value {
my ($self,$args) = @_;
my $value = \$args->{'value'};
my $debug = \$args->{'debug'};
my $rc = ${$value};
if ( ${$debug} ) { print {*STDOUT} "[DEBUG] _parse_config_value | value = ${$value}\n" or croak $ERRNO; }

if ( ${$value} =~ /^(?:no|NO|[0]|false|false)$/smx ) { $rc = undef; };
#if ( ${$value} =~ /^(?:yes|YES|[1]|true|TRUE)$/smx ) { $rc = ${$value} };

return ($rc);
}

sub preparepath {
my ($self,$args) = @_;
my $path = \$args->{'path'};
my $debug = \$args->{'debug'};
if ( ! ${$path} ) { return ('preparepath_fail'); }
my $returnline=q{};
# check if path an existing directory
if ( -d ${$path} ) {
  $returnline = ${$path} ;
}

# check if path an symbol link
if ( ( $returnline ne q{} ) and ( -l $returnline ) ) {
  my $newpath = readlink $returnline ;
  $returnline = $newpath;
}

# check if path have at the end an /
if ( $returnline =~ /\/$/smx ) {
  $returnline =~ s/\/$//smx ;
}
return ($returnline) ;
} # end sub

sub prepare_crop {
my ($self,$args) = @_ ;
my $oldcrop = \$args->{'crop'};
my @new_crop = ();
my ($org_top,$org_bottom,$org_left,$org_right ) = split /\//smx,${$oldcrop};

# set both crops ( per top/ bottom and Left/Rigth) on larger crop found by handbrake, to prevent crop is only left and not right side for example
foreach my $a ( 0..1 ) {$new_crop[$a] = $org_top > $org_bottom ? $org_top : $org_bottom ;}
foreach my $b ( 2..DREI ) {$new_crop[$b] = $org_left > $org_right ? $org_left : $org_right ;}
# rounding by modulo 8( sprintf "%.0f" , ( $probe_memory_ammount_Mbyte / 25 )) * 25 ;
foreach my $c ( @new_crop ) { $c = ( sprintf '%.0f' , ( ( $c / ACHT ) * ACHT ) ) } ;
$self->message({msg=>"crop old : $org_top/$org_bottom/$org_left/$org_right crop new : @new_crop",verbose=>'v',}) ;
my $param_crop = "$new_crop[0]:$new_crop[1]:$new_crop[2]:$new_crop[DREI]" ;
undef @new_crop;

return ($param_crop);

}
sub recalculate_video_bitrate {
my ($self,$args) = @_ ;
my $frames = \$args->{'frames'} ;
my $fps = \$args->{'fps'};
my $aac_nr = \$args->{'aac_nr'};
my $aac_bitrate = \$args->{'aac_bitrate'}; # in kbit
my $ac3_nr = \$args->{'ac3_nr'};
my $ac3_bitrate = \$args->{'ac3_bitrate'}; # in kbit
my $wish_bitrate = \$args->{'wish_bitrate'} ; # in kbit


#print "frames 	    = ${$frames}\n";
#print "fps    	    = ${$fps}\n";
#print "aac_nr 	    = ${$aac_nr}\n";
#print "aac_bitrate  = ${$aac_bitrate}\n";
#if ( ( ${$ac3_bitrate} ) and ( ${$ac3_nr} ) ) { 
#print "ac3_bitrate  = ${$ac3_bitrate}\n"; 
#print "ac3_nr       = ${$ac3_nr}\n";
#}
#print "wish_bitrate = ${$wish_bitrate}\n";
#
#

my $video_wish_bitrate_inbyte = ( ( ${$wish_bitrate} * EINSNULLZWEIVIER ) / ACHT );
#print "video_wish_bitrate_inbyte $video_wish_bitrate_inbyte\n";
my $aac_bitrate_inbyte = ( ( ${$aac_bitrate} * EINSNULLZWEIVIER ) / ACHT );
#print "aac_bitrate_inbyte $aac_bitrate_inbyte\n";

my $ac3_bitrate_inbyte = q{};
if (${$ac3_bitrate} ) {
  $ac3_bitrate_inbyte = ( ( ${$ac3_bitrate} * EINSNULLZWEIVIER ) / ACHT )  ;
#  print "ac3_bitrate_inbyte $ac3_bitrate_inbyte\n";
}

# Calculate Size of AAC Files
my $audiokbyte = 0 ;
my $ac3_kbyte_sec = q{};
my $ac3_kbytesize = 0;
my $round_memory_ammount_mbyte = 0;

if ( ( ${$aac_nr} ) and ( ${$aac_nr} > 0 ) ) {
#  $audiokbyte = sprintf '%.8f' , ( ${$aac_bitrate} * ${$frames} / ${$fps} / ACHT ) ; # ohne Overhead
#  $audiokbyte = $audiokbyte *  $aac_nr ;
#my $a=$aac_bitrate_inbyte / $EINSNULLZWEIVIER;
#my $b=${$frames} / ${$fps} ;
#my $c = $b * ${$aac_nr};
  $audiokbyte = sprintf '%.8f' , ( $aac_bitrate_inbyte / EINSNULLZWEIVIER ) * ( ${$frames} / ${$fps} )  ; # ohne Overhead
  $audiokbyte = $audiokbyte * ${$aac_nr} ;
#my $test = $a * $b;
#print "$test\n";

#print "audiokbyte $audiokbyte \n";
}

#  print "\$AudioKbyte $AudioKbyte\n" ;

# Calculate Size of Ac3 Files
if ( (${$ac3_nr} ) and ( ${$ac3_nr} > 0 ) ) {
#  $ac3_kbyte_sec = $ac3_bitrate / $ACHT ;
#  $ac3_kbytesize = sprintf '%.8f' , ( $ac3_kbyte_sec  * ${$frames}  / ${$fps} ) ;
#  $ac3_kbytesize = $ac3_kbytesize * ${$ac3_nr} ;

  $ac3_kbytesize = sprintf '%.8f' , ( $ac3_bitrate_inbyte / EINSNULLZWEIVIER ) * ( ${$frames} / ${$fps} ) ;
  $ac3_kbytesize = $ac3_kbytesize * ${$ac3_nr} ;
#print "ac3_kbytesize $ac3_kbytesize\n";
}
#  print "\$ac3_kbyteSize $ac3_kbyteSize\n" ;
# Memory count 
my $minutes = ( ( ${$frames} / ${$fps} ) / SECHSNULL ) ;
#print "*minutes $minutes\n";

my $video_kbyte_sec = ( $video_wish_bitrate_inbyte / EINSNULLZWEIVIER ) ;
#print "video kbyte sec $video_kbyte_sec\n";

my $video_kbyte_size = ( $video_kbyte_sec * ( ${$frames} / ${$fps} ) );
#print "video kbyte size $video_kbyte_size\n";

my $probe_memory_ammount_kbyte = $video_kbyte_size + $ac3_kbytesize + $audiokbyte ;

#print "probe memory ammount kbyte $probe_memory_ammount_kbyte\n";

my $probe_memory_ammount_mbyte = sprintf '%i' , ($probe_memory_ammount_kbyte / EINSNULLNULLNULL );

$self->message ({msg=>"\$probe_memory_ammount_mbyte $probe_memory_ammount_mbyte",}) ;

# rounding
  given ($probe_memory_ammount_mbyte) {
    when ( $_ < ZWEINULL ) {
      $round_memory_ammount_mbyte = ( sprintf '%.0f' , (( $probe_memory_ammount_mbyte / 1 )  * 1 ) ) ;
    }
    when ( $_ < EINSNULLNULL ) {
      $round_memory_ammount_mbyte = ( sprintf '%.0f' , (( $probe_memory_ammount_mbyte / FUENF )  * FUENF  ) );
    }
    when ( $_ < SECHSNULLNULL ) {
      $round_memory_ammount_mbyte = ( sprintf '%.0f' , (( $probe_memory_ammount_mbyte / ZWEIFUENF ) * ZWEIFUENF) );
    }
    when ( $_ >= SECHSNULLNULL ) {
      $round_memory_ammount_mbyte = ( sprintf '%.0f' , (( $probe_memory_ammount_mbyte / FUENFNULL ) * FUENFNULL) ) ;
    }
  }
  $self->message ({msg=>"\$round_memory_ammount_Mbyte $round_memory_ammount_mbyte",});

my $round_memory_ammount_kbyte = $round_memory_ammount_mbyte * EINSNULLZWEIVIER ;
$round_memory_ammount_kbyte = $round_memory_ammount_kbyte * EMPIRIC_FACTOR ; # empiric factor add 

#$round_memory_ammount_kbyte = sprintf '%.0f', $round_memory_ammount_kbyte;
#print "round_memory_ammount_kbyte $round_memory_ammount_kbyte \n"; #(* $EMPIRIC_FACTOR)\n";

#my $round_memory_ammount_video_kbit = ( $round_memory_ammount_kbyte - $ac3_kbytesize - $audiokbyte ) * $ACHT ;
my $a = $round_memory_ammount_kbyte - $ac3_kbytesize - $audiokbyte;

my $b = $a * EINSNULLZWEIVIER; # alles in byte
my $c = $b * ACHT; # alles in bit
my $d = $c / ( ${$frames} / ${$fps} );

my $e = sprintf '%.0f' ,  ( $d / EINSNULLZWEIVIER ); # # ergebnis in kbit

#my $round_memory_ammount_video_kbit = ( ( ( ( $round_memory_ammount_kbyte - $ac3_kbytesize - $audiokbyte ) / $EINSNULLZWEIVIER ) / $ACHT ) ) ;
#my $round_memory_ammount_video_kbit_sec = sprintf '%.0f' , ( $round_memory_ammount_video_kbit / ( ${$frames} / ${$fps} ) ) ;

#print "-> \$round_memory_ammount_video_kbit_sec $round_memory_ammount_video_kbit_sec\n $e\n";
#print "-> \$round_memory_ammount_video_kbit_sec $e\n";

#return ($round_memory_ammount_video_kbit_sec , $round_memory_ammount_mbyte) ;
return ($e , $round_memory_ammount_mbyte) ;
}

1;

__END__

=head1 NAME

  Traco::Traco

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


