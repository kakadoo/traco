#!/usr/bin/perl -w
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/usr/local/bin/tracosrv.pl $
# $Id: Holger Glaess $
# $HeadURL www.glaessixs.de/projekte/vdrtranscode $ 
# $Date 29/03/2011 $

# some code for tracosrv.pl from faup@vdr-portal.de
# 2011-02-28
# great thanks to this superb howto :
# http://trac.handbrake.fr/wiki/CLIGuide

use strict;
use warnings;
use Carp;
use English '-no_match_vars';
use lib 'lib/';
#use Getopt::Long:
use Fcntl qw(:flock) ;
use Proc::Daemon 0.11;
use File::Basename ;
use Traco::Traco 0.20;
#use Data::Dumper ;

# now feature from 5.10
use feature qw/switch/;

our $VERSION = '0.23';

use constant HD => { 1920 => 1080, 1280 => 720, 720 => 480, };
# declarations
my $tracoenv = {};
my $videostatus = {};
# defaults
$tracoenv->{'configfile'} = '/etc/vdr/traco.conf' ;
$tracoenv->{'daemon_flag'} = '1';
$tracoenv->{'debug_flag'} = '0';
#$tracoenv->{'verbose_flag'} = q{};
$tracoenv->{'interval'} = 5 ;
$tracoenv->{'pidfile'} = '/var/run/vdr/tracosrv.pid';
$tracoenv->{'setcpu'} = q{};
$tracoenv->{'fpstype'} = 'vdr';
# set default profile 
$tracoenv->{'defaultprofile'} = 'SD';
# nice default
$tracoenv->{'nice'} = '20';
$tracoenv->{'vdrversion'} = '1.7';
$tracoenv->{'vdruid'} = $UID;

my $z=0;
#my $homedir = getcwd();

my $daemon = Proc::Daemon->new();
my $mainpid = q{};

# end declarations


while ( defined $ARGV[$z] ) {
  given ($ARGV[$z]) {
    when ( /^[-]v+$/smx ) {
      $tracoenv->{'verbose_flag'}=$_;
    }
    when ( /^(?:[-][-]debug|[-]d)$/smx ) {
      $tracoenv->{'debug_flag'} = '1';
      $tracoenv->{'verbose_flag'} = 'vvv';
    }
    when ( /^(?:[-][-]forground|[-]f)$/smx ) {
      $tracoenv->{'daemon_flag'} = '0';
    }
    when ( /^(?:[-][-]help|[-]h)$/smx ) {
    _myhelp ();
    exit 0 ;
    }
    when ( /^(?:[-][-]config|[-]c)$/smx ) {
      my $f=$z+1;
      $tracoenv->{'configfile'} = $ARGV[$f] ;
      $z++;
    }
  } # end given 
  $z++;
} # end while ARGV
#

# init Vdrtranscode(traco) object
my $traco=Traco::Traco->new({debug=>$tracoenv->{'debug_flag'},});
my $config = \$traco->parseconfig({config=>$tracoenv->{'configfile'},debug=>$tracoenv->{'debug_flag'},});
# setup facilitiy / priority for syslog
$traco->setup({facility=>${$config}->{'facility'},priority=>${$config}->{'priority'},});

# wenn daemon dann ausgabe nach syslog sonst STDOUT
$traco->setup({daemon=>$tracoenv->{'daemon_flag'},verboselevel=>$tracoenv->{'verbose_flag'},});
$traco->message ({msg=>"use configfile $tracoenv->{'configfile'}",v=>'v',});


# override default profile from config
if (${$config}->{'defaultprofile'} ) {
  $tracoenv->{'defaultprofile'} = ${$config}->{'defaultprofile'};
}
# override default fpstype from config
if (${$config}->{'fpstype'} ) {
  $tracoenv->{'fpstype'} = ${$config}->{'fpstype'};
}

# get vdr user 
if ( ${$config}->{'vdr_user'} ) {
	my $new_uid = getpwnam ${$config}->{'vdr_user'};
	if ( $new_uid ) {
	  $tracoenv->{'vdruid'} = $new_uid;
  	}
} else {
  $traco->message({msg=>"missing vdr_user at your system use default $tracoenv->{'vdruid'}",}) ;
}

# get path from config
# check if directorys are symbolic links and replace it with followd link
#
my $indirrc = \$traco->preparepath({path=>${$config}->{'Indir'},});
my $outdirrc = \$traco->preparepath({path=>${$config}->{'Outdir'},});

if ( ${$indirrc} ) {
  $tracoenv->{'indir'} = ${$indirrc};
} else {
  $traco->message({msg=>"${$config}->{'Indir'} not found or is not a Directory, check please...",}) ;
  _leave () ;
}
if ( ${$outdirrc} ) {
  $tracoenv->{'outdir'} = ${$outdirrc};
} else {
  $traco->message({msg=>"${$config}->{'Outdir'} not found or is not a Directory, check please...",}) ;
  _leave () ;
}

$traco->message ({msg=>"debug $tracoenv->{'debug_flag'}",v=>'vvv'},);

# overwrite nice default 
if ( ${$config}->{'nice_level'} ) {
  $tracoenv->{'nice'} = ${$config}->{'nice_level'};
}
$traco->message ({msg=>"nice $tracoenv->{'nice'}",v=>'vvv',});

# find binarys 
# eg. /usr/bin/HandBrakeCLI
my $runexternal = \$traco->_runexternal({line=>'which HandBrakeCLI',debug=>$tracoenv->{'debug_flag'},});

# runexternel returns first the output of the external command if exist then 
# the exit code of the external command
if ( ${$runexternal}->{'exitcode'} != 0 ) {
  $traco->message ({msg=>'handbrake not found , please check!',});
  exit 1;
} elsif ( $#{${$runexternal}->{'returndata'} } >= 0 ) {
  $tracoenv->{'hb_bin'} = ${$runexternal}->{'returndata'}->[0];
  $traco->message ({msg=>"bin $tracoenv->{'hb_bin'}",v=>'vvv'});
}

# end find binarys ##################

# get vdr version from config if available
if ( ${$config}->{'vdrversion'} ) {
	$tracoenv->{'vdrversion'} = ${$config}->{'vdrversion'};
}

$traco->message({msg=>"vdr version $tracoenv->{'vdrversion'}",v=>'v',}) ;

if ( ${$config}->{'setcpu'} ) {
  my $setcpu = \$traco->setcpuoptions({config=>${$config}->{'setcpu'},debug=>${$config}->{'debug_setcpuoptions'},maxcpu=>${$config}->{'maxcpu'},});
  $tracoenv->{'setcpu'} = ${$setcpu};
  $traco->message ({msg=>"handbrake use as cpu option $tracoenv->{'setcpu'}",v=>'v',});
}

########## end config defaults
if ( $tracoenv->{'daemon_flag'} == 1) {
  is_running ();
  $daemon = Proc::Daemon->new ( pid_file => $tracoenv->{'pidfile'} );
  $mainpid = $daemon->Init ({ work_dir => $tracoenv->{'indir'} });
  if ( not ( $mainpid  ) ) {
    $EUID = $tracoenv->{'vdruid'};
    $UID = $tracoenv->{'vdruid'};
    $traco->message ({msg=>"fork to the background pid $PID with EUID = $EUID",});
    $traco->_runexternal({ line=>"renice -n $tracoenv->{'nice'} -p $PID", debug=>$tracoenv->{'debug_flag'},});

    while (1) {
      runmain ();
      sleep $tracoenv->{'interval'};
    }
  }
} else {
  $traco->message ({msg=>'no fork to the background',});
  $EUID = $tracoenv->{'vdruid'};
  $UID = $tracoenv->{'vdruid'};
    while (1) {
      runmain ();
      sleep $tracoenv->{'interval'};
    }
}

sub is_running {
my @plist = $traco->_runexternal({line=>'ps -ax',});
my @tracop = grep { /tracosrv/smx } @plist;
if ($#tracop >= 0 ) {
  print {*STDOUT} "server already running\n" or croak $ERRNO;
  exit 1;
}
undef @plist;
undef @tracop;
return ();
}

sub runmain {
#$SIG{TERM} = sub {  };
local $SIG{TERM} = \&_leave ; # exit clean on Signal kill PID
local $SIG{INT} = \&_leave ; # exit clean on Signal Str+C
local $SIG{CHLD} = 'IGNORE' ;

# find info or info.vdr
# reset on every new main loop

my @videolist = \$traco->getfilelist({dir=>$tracoenv->{'indir'},
					      skiplinks=>'true',
					      debug=>${$config}->{'debug_getfilelist'},
					      });
#

my @videoqueue = ();

# check for vdrtranscode.xml if exist and get status from this video
for my $v (@videolist) {
#  my $videofile = basename(${$v});
  my $videopath = dirname (${$v});
  $traco->message ({msg=>"proccess queue item $videopath",v=>'vvv',});
  my $indir = $tracoenv->{'indir'};
  if ( $videopath =~ /^($indir)$/smx ) { next ; }
  # check again if directory exist , maybe delete by osd
  if ( not ( -d $videopath ) ) { next ; };

  # if $videopath/vdrtranscode.xml exist -> read and parse 
  # else read info.(vdr) parse them and  vdrtranscode.xml
  if ( -e "$videopath/vdrtranscode.xml" ) {
    my $st = \$traco->getfromxml({file=>"$videopath/vdrtranscode.xml",field=>'status',debug=>$tracoenv->{'debug_flag'}});
    my $status = ${$st} || 'offline';
    my @tmp = grep { /\Q$videopath/smx } @videoqueue ; # save for double entrys in queue
    if ( $#tmp < 0 ) { push @videoqueue,"$videopath $status"; }
   }
 else {
    if ( ( -e "$videopath/info" ) or ( -e "$videopath/info.vdr" ) ) {
      my $createxmlrc = \$traco->createvdrtranscodexml({dir=>$videopath,
							debug=>${$config}->{'debug_createvdrtranscodexml'},
							profile=>$tracoenv->{'defaultprofile'},
							});
      $traco->message ({msg=>${$createxmlrc},v=>'vvv',});
      next ;
    }
  }
} # end foreach @videolist

_proccessqueue (@videoqueue);

undef @videolist;
undef @videoqueue;
return ();
} # end _main
sub forker {
my $dir = shift;

      my $trrc = q{};
      my $forkerpid = $daemon->Fork();
      if ( $forkerpid == 0 ) {
      _createlck($dir);
      $traco->_runexternal({ line=>"renice -n $tracoenv->{'nice'} -p $PID", debug=>$tracoenv->{'debug_flag'},});
				  
	if ( ${$trrc} =~ /[_]done$/smx ) {
	  _removelck($dir);
	  exit 0; # exit for fork
	}
      }
      waitpid $forkerpid,0;
      return;
}

sub _createlck {
	my $dir = shift;
	my $lockfilerc = \$traco->writelockfile({dir=>$dir,});
	$traco->message ({msg=>"create lockfile  in $dir = ${$lockfilerc}",v=>'v', });
	return;
}
sub _removelck {
my $dir = shift;
my $rcunlock = \$traco->removelockfile ({dir=>$dir,});
$traco->message ({msg=>"remove lockfile in $dir = ${$rcunlock}",v=>'v',});
return ;
}

sub _proccessqueue {
my @videoqueue = @_;
my $rc = q{};


# proccess video by status
foreach my $st (@videoqueue) {
  my ($dir,$status) = split /\s/smx , $st;
  
  # if $dir/vdrtranscode.lck exist do nothing
  if ( -e "$dir/vdrtranscode.lck" ) {
    $traco->message ({msg=>"lockfile exist in $dir do nothing",v=>'v',});
    next ;
  }
  
 $traco->message ({msg=>"$dir have status $status",v=>'vv',});
  given ($status) {
    # job not edited by vdr ( tracoadm )
    when ( /^(?:offline|transcodedone|YourPictureIsReadyToView)$/smx ) {
      next ;
    }
    # if vdrtranscode is proccessing a transcode , next
    when ( /^proccessing$/smx ) { last; }
    # job have multiple recording files and vdr ( vdrtranscodeadm ) prepare the job
    when ( /^renameaftertranscode$/smx) {
      my $renamerc = \$traco->rename_and_store({dir=>$dir,
						filenameformat=>${$config}->{'filenameformat'},
						destination=>$tracoenv->{'outdir'},
						debug=>$tracoenv->{'debug_flag'},
						});
      if (${$renamerc} eq '_rename_and_store_done') {
       $traco->changexmlfile({file=>"$dir/vdrtranscode.xml",
				     action=>'change',
				     field=>'status',
				     to=>'YourPictureIsReadyToView',
				     debug=>$tracoenv->{'debug_flag'},
				     });
      }
    last;
    }
    when ( /^joinfiles$/smx ) {
      my $files = \$traco->getfromxml({file=>"$dir/vdrtranscode.xml",
					      field=>'files',
					      debug=>$tracoenv->{'debug_flag'},
					      });
	if ( ( defined ${$files} ) and ( ${$files} ne q{} ) ) {
		_createlck($dir);
      $rc=\$traco->_joinfiles({dir=>$dir,files=>${$files},debug=>$tracoenv->{'debug_flag'},});
      if (${$rc} eq 'joindone') {
      _removelck($dir);
	$traco->changexmlfile({file=>"$dir/vdrtranscode.xml",
					action=>'change',
					field=>'status',
					to=>'online',
					debug=>$tracoenv->{'debug_flag'},
					});
	$videostatus->{$dir} = 'online';
      }
      $rc=q{};
      undef $files;
      } else {
	$traco->message ({msg=>"no field \<files\> found in vdrtranscode.xml or is field is empty in $dir",});
      }
      last;
    } # end when joinfiles
    when ( /^prepare_traco_ts$/smx ) {
		_createlck($dir);
      my $tracotsrc=\$traco->prepare_traco_ts({source=>$dir,debug=>$tracoenv->{'debug_flag'},
						vdrversion=>$tracoenv->{'vdrversion'},
						fpstype=>$tracoenv->{'fpstype'},
						handbrake=>$tracoenv->{'hb_bin'},
						nice=>$tracoenv->{'nice'},
					      });
      $traco->message ({msg=>"${$tracotsrc} in $dir",});
      if ( ${$tracotsrc} !~ /[_]done$/smx ) {
          $traco->changexmlfile({file=>"$dir/vdrtranscode.xml",
                                        action=>'change',
                                        field=>'status',
                                        to=>'offline',
                                        debug=>$tracoenv->{'debug_flag'},
                                      });
      }
    	_removelck($dir);                               

      last;
    }
    when ( /^cutfiles$/smx ) {
      my $marksfile=q{};
      if ( -e "$dir/marks" ) { $marksfile="$dir/marks";}
      if ( -e "$dir/marks.vdr" ) { $marksfile="$dir/marks.vdr";}
      if ( $marksfile ne q{} ) {
      _createlck($dir);
      my $cutrc=\$traco->combine_ts ({source=>$dir,
					      target=>"$dir/vdrtranscode.ts",
					      debug=>$tracoenv->{'debug_flag'},
					      vdrversion=>$tracoenv->{'vdrversion'},
					      fpstype=>$tracoenv->{'fpstype'},
					      handbrake=>$tracoenv->{'hb_bin'},
					      nice=>$tracoenv->{'nice'},
					      marksfile=>$marksfile,
					      });
	if ( ${$cutrc} eq 'combine_ts_done' ) {
		_removelck($dir);
	  $traco->changexmlfile({file=>"$dir/vdrtranscode.xml",
					action=>'change',
					field=>'status',
					to=>'online',
					debug=>$tracoenv->{'debug_flag'},
				      });
	  $videostatus->{$dir} = 'online';
	} else {
	  $traco->message ({msg=>"returncode ${$cutrc} in $dir",});
	}
      $cutrc=q{};
      } else {
        $traco->message ({msg=>"no marks file found cant start cutfiles in $dir",});
      }
      last;

    }
    # wait for preparing video destination 
    when ( /^online$/smx ) {
      $videostatus->{$dir} = $status;
    }
    # we found a waiting file and vdr ( vdrtranscodeadm ) prepare the job and release for proccessing
    when ( /^ready$/smx && $tracoenv->{'daemon_flag'} == 1 ) {
      $videostatus->{$dir} = 'proccessing';
      my $trrc = q{};
      my $transcodepid = $daemon->Fork();
      if ( $transcodepid == 0 ) {
      _createlck($dir);
	my $prerc = \_preproccess($dir);
	if (${$prerc} =~ /[_]done$/smx ) {
	  $trrc = \_transcodevideo ($dir);
	  $traco->message ({msg=>"return from _transcodevideo $dir = ${$trrc}",});
	}
	if (${$trrc} =~ /[_]done$/smx ) {
	  _removelck($dir);
	  exit 0; # exit for fork
	}
      }
      waitpid $transcodepid,0;
      _postproccess ({dir=>$dir,debug=>${$config}->{'debug_postproccess'},});
      last;
    }
    when ( /^ready$/smx && $tracoenv->{'daemon_flag'} == 0 ) {
      $videostatus->{$dir} = 'proccessing';
      my $trrc;
      _createlck($dir);
      my $prerc = \_preproccess($dir);
      if (${$prerc} =~ /[_]done$/smx ) {
	$trrc = \_transcodevideo ($dir);
	$traco->message ({msg=>"return from _transcodevideo $dir = ${$trrc}",});
      }
      if (${$trrc} =~ /[_]done$/smx ) {
      _removelck($dir);
	_postproccess ({dir=>$dir,debug=>${$config}->{'debug_postproccess'},});
      }
      last;
    }
  } # end given $st
} # end foreach @videoqueue
undef @videoqueue;
return ();
} # end sub _proccessqueue

sub _preproccess {
my $proccessvideodir = shift ;

if ( not ( -e "$proccessvideodir/vdrtranscode.ts" ) ) {
  $traco->message ({msg=>"in $proccessvideodir ,no vdrtranscode.ts exist , stop _preproccess for transcodevideo , set status to offline",});
  
  $traco->changexmlfile({file=>"$proccessvideodir/vdrtranscode.xml",
				action=>'change',
				field=>'status',
				to=>'offline',
				debug=>$tracoenv->{'debug_flag'},
				});
  return ('filenotexist');
}
$traco->changexmlfile({file=>"$proccessvideodir/vdrtranscode.xml",
				action=>'change',
				field=>'status',
				to=>'proccessing',
				debug=>$tracoenv->{'debug_flag'},
				});

return ('_preproccess_done');
}


sub _transcodevideo {
my $proccessvideodir = shift ;

$traco->message ({msg=>'read and prepare profile',}) ;

my $profile = \$traco->prepareprofile ({
	hb_bin=>$tracoenv->{'hb_bin'},
	nice=>$tracoenv->{'nice'},
	config=>${$config},
	file=>$proccessvideodir,
	profile=>$tracoenv->{'defaultprofile'},
	debug=>$tracoenv->{'debug_flag'},
      }) ;
${$profile}->{'setcpu'} =  $tracoenv->{'setcpu'};

$traco->message ({msg=>"analyse $proccessvideodir/vdrtranscode.ts",}) ;

my $hba = \$traco->handbrakeanalyse({file=>"$proccessvideodir/vdrtranscode.ts",
						nice=>$tracoenv->{'nice'},
						handbrake=>$tracoenv->{'hb_bin'},
						kbps=>'true',
						debug=>$tracoenv->{'debug_flag'},
						fpstype=>$tracoenv->{'fpstype'},
						audiotrack=>${$profile}->{'audiotracks'},
						drc=>${$profile}->{'DRC'},
						aac_bitrate=>${$profile}->{'AAC_Bitrate'},
						});

my $totalframes = $traco->getfromxml({file=>"$proccessvideodir/vdrtranscode.xml",field=>'totalframes',debug=>$tracoenv->{'debug_flag'},});

if ( not ( $totalframes ) ) {
# check marks and resolve start and end point
# if marks not available use start / stop time form info
  my $marksfile = q{};
  if ( -e "$proccessvideodir/marks" ) { $marksfile="$proccessvideodir/marks";}
  if ( -e "$proccessvideodir/marks.vdr" ) { $marksfile="$proccessvideodir/marks.vdr";}
  if ( $marksfile ne q{} ) {
    my $vdrmarks = \$traco->parsevdrmarks({dir=>$proccessvideodir,
				    fps=>${$hba}->{'fps'},
				    duration=>${$hba}->{'duration'},
				    debug=>$tracoenv->{'debug_flag'},
				    marksfile=>$marksfile,
				   });
   $totalframes =  ${$vdrmarks}->{'totalframes'};
  }
}

if ( ( not ( ${$profile}->{'crop'} ) ) or ( ${$profile}->{'crop'} !~ /^auto$/smx ) ) {
  ${$profile}->{'crop'} = $traco->prepare_crop({crop=>${$hba}->{'autocrop'},});
}

#print Dumper $tracoenv;
#print Dumper $profile;
#print Dumper $hba;

$traco->message({msg=>"container ${$profile}->{'container'}",verbose=>'v',});
$traco->message({msg=>"name ${$profile}->{'name'}",verbose=>'v',});
$traco->message({msg=>"quality ${$profile}->{'quality'}",verbose=>'v',});
$traco->message({msg=>"audiotracks ${$profile}->{'audiotracks'}",verbose=>'v',});
$traco->message({msg=>"fps ${$hba}->{'fps'}",verbose=>'v',}) ;
$traco->message({msg=>"crop ${$profile}->{'crop'}",verbose=>'v',}) ;
$traco->message({msg=>"modulus ${$profile}->{'modulus'}",verbose=>'v',}) ;
$traco->message({msg=>"setcpu ${$profile}->{'setcpu'}",verbose=>'v',}) ;
$traco->message({msg=>"codec ${$profile}->{'codec'}",verbose=>'v',}) ;
if ( ${$profile}->{'codecopts'} ) {
$traco->message({msg=>"codecopts ${$profile}->{'codecopts'}",verbose=>'v',}) ;
}

if ( ${$profile}->{'largefile'} ) {
$traco->message({msg=>"largefile ${$profile}->{'largefile'}",verbose=>'v',}) ;
}
# recalculate Videobitrate to match round Mbyte Sizes ( cosmetic programming )
# $frames 
# $fps 
# $aac_nr 
# $aac_bitrate 
# $ac3_nr 
# $ac3_bitrate 
# $wish_bitrate 
my ( $recalc_video_bitrate , $target_mbyte_size ) = q{};

if ( ${$profile}->{'quality'} !~ /^(?:rf|RF)[:]\d{1,2}$/smx ) {
if ( ( ${$hba}->{'audioopts'}->{'ac3tracks'} > 0 ) and ( ${$hba}->{'audioopts'}->{'kbps'} ) ) {
( $recalc_video_bitrate , $target_mbyte_size ) = \$traco->recalculate_video_bitrate ({
  frames=>$totalframes ,
  fps=>${$hba}->{'fps'} ,
  aac_nr=>${$hba}->{'audioopts'}->{'mp2tracks'},
  aac_bitrate=>${$profile}->{'AAC_Bitrate'}, # in kbit
  ac3_nr=>${$hba}->{'audioopts'}->{'ac3tracks'},
  ac3_bitrate=>${$hba}->{'audioopts'}->{'kbps'} , # in kbps
  wish_bitrate=>${$profile}->{'quality'}, }) ; # in kbbps
} else {
( $recalc_video_bitrate , $target_mbyte_size ) = \$traco->recalculate_video_bitrate ({
  frames=>$totalframes ,
  fps=>${$hba}->{'fps'} ,
  aac_nr=>${$hba}->{'audioopts'}->{'mp2tracks'},
  aac_bitrate=>${$profile}->{'AAC_Bitrate'},
  wish_bitrate=>${$profile}->{'quality'}, }) ; # in kbbps
}
}
## strucure of proccesing line
## HandBrakeCLI -i /video/Wir_sind_Kaiser_-_Best_of/2010-10-26.21.55.15-0.rec/00001.ts  -o ./test3.mp4 -e x264 -O -b 500 -2 -T -x ref=2:mixed-refs:bframes=2:b-pyramid=1:
## weightb=1:analyse=all:8x8dct=1:subme=7:me=umh:merange=24:trellis=1:no-fast-pskip=1:no-dct-decimate=1:direct=auto -5 -B 128  --stop-at frame:3000 --strict-anamorphic

my $newdir=$proccessvideodir;
$newdir =~ s/[&]/\\&/gmixs;
my $runline;
if ( ${$profile}->{'quality'} !~ /^(?:rf|RF)[:]\d{1,2}$/smx ) {
  $runline=\$traco->buildrunline({profile=>${$profile},
				    dir=>$newdir,
				    hba=>${$hba},
				    recalc_video_bitrate => ${$recalc_video_bitrate},
				    target_mbyte_size => ${$target_mbyte_size},
				    debug=>${$config}->{'debug_buildrunline'},
			 	    useclassic=>${$config}->{'use_classic_profile'},
				  });
} else {
  $runline=\$traco->buildrunline({profile=>${$profile},
				    dir=>$newdir,
				    hba=>${$hba},
				    debug=>${$config}->{'debug_buildrunline'},
			 	    useclassic=>${$config}->{'use_classic_profile'},
				  });
}

my $hbrc;
if ( ${$config}->{'writelog'} ) {
 $hbrc = \$traco->run_handbrake({execline=>${$runline},debug=>$tracoenv->{'debug_flag'},writelog=>"$newdir/handbrake.log",});
} else {
 $hbrc = \$traco->run_handbrake({execline=>${$runline},debug=>$tracoenv->{'debug_flag'},});
}
#if (${$hbrc} eq 'hbdone') {
#  _postproccess ({dir=>$proccessvideodir,debug=>${$config}->{'debug_postproccess'},});
#}
$runline = undef;
$profile = undef;
$hba = undef;
return ('_transcodevideo_done');
} # end sub _proccessqueue

sub _postproccess {
my $args = shift;
my $postproccessdir = $args->{'dir'};
my $dbg = \$args->{'debug'};
my $returnline = '_postproccess_done';


if ( ${$config}->{'executeafter'} ) {
      my $execafterpid = $daemon->Fork();
      if ( $execafterpid == 0 ) {
	my $rc = $traco->_runexternal({
	  line=>"${$config}->{'executeafter'} $postproccessdir $tracoenv->{'outdir'}",
	  debug=>$tracoenv->{'debug_flag'},
	 });
        $traco->message ({msg=>"executeafter | return from _runexternal = ${$rc}->{'exitcode'}",});
	if (${$rc}->{'exitcode'} == 0 ) {
	  exit 0; # exit for fork
	}
      }
      waitpid $execafterpid,0;
}

$traco->changexmlfile({file=>"$postproccessdir/vdrtranscode.xml",
				action=>'change',
				field=>'status',
				to=>'renameaftertranscode',
				debug=>$tracoenv->{'debug_flag'},
				});

$traco->message ({msg=>"_postproccess|return = $returnline",v=>'vvv',});
return ($returnline);
}

sub _leave {
  $traco->message({msg=>'quit...',}) ;
  if ( -f $tracoenv->{'pidfile'} ) {
    unlink $tracoenv->{'pidfile'} ;
  }
  exit 1 ;
}

sub _myhelp {
  while (<DATA>) {
    print {*STDOUT} "$_\n" or croak $ERRNO;
  }
  return () ;
}

#################################################################

1;
__DATA__

vdrtranscode_server.pl
$ vdrtranscode_server 
  [--verbose] or -v - mutiple v increase the verboselevel
  [--help] or -h 
  [--forground ] or -f
  [--config] or -c

  


