package Traco::Tracoprofile;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Tracoprofile.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#use Data::Dumper;
use English '-no_match_vars';
use Carp;
use feature qw/switch/;
require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(getprofile prepareprofile _calculate_bitrate);

$VERSION = '0.19';
use constant { VIERACHTNULL => 480, SECHSVIERNULL => 640, };
#
# 0.18 inital version
#
# see 
#
# http://www.winxdvd.com/resource/handbrake-video-quality-settings.htm
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

my $profile = {
default => {
	    codecopts=>'-x ref=2:mixed-refs:bframes=2:b-pyramid=1:weightb=1:analyse=all:8x8dct=1:subme=7:me=umh:merange=24:trellis=1:no-fast-pskip=1:no-dct-decimate=1:direct=auto',
	    codec=>'-2 -T -e x264',
	    quality=>{ UVHQ =>'7000', VHQ =>'3700',HQ =>'1200',MQ =>'800',LQ =>'600',VLQ =>'400' },
	    codec_ratio=> {mpeg4 => ' 0.0135', h264 => '0.012345',},
	    quality_ratio => { HQ => '0.35' , VHQ => '0.55', UVHQ => '1.0',},
	    keys => 'shortname name resolution container pixel ypixel anamorph modulus quality crop largefile audiotracks codec codecopts',
	  },
HD => { shortname=>'HD',
	name=>'HD (1080p) Profile with UVHQ bitrate',
	resolution=> '1080p',
	container=>'mp4',
	pixel => '1920',
	ypixel => '1080',
	anamorph=>'--loose-anamorphic',
	modulus=>'8',
        quality=>'UVHQ',
	audiotracks=>'all',
      },
smallHD => { shortname=>'smallHD',
	     name=>'HD (720p) Profile with VHQ bitrate',
	     resolution=> '720p',
	     container=>'mp4',
	     pixel => '1280',
	     ypixel => '720',
	     anamorph=>'--loose-anamorphic',
	     modulus=>'8',
	     quality=>'VHQ',
	     audiotracks=>'all',
	    },
SD => { shortname=>'SD',name=>'SD (480p) Profile with HQ Bitrate',
	resolution=>'480p',
	container=>'mp4',
	pixel => '852',
	ypixel => '480',
	anamorph=>'--loose-anamorphic',
	modulus=>'8',
        quality=>'HQ',
	audiotracks=>'all',},

PAL => { shortname=>'PAL',name=>'SD (PAL Resolution) Profile with HQ Bitrate',
	resolution=>'PAL',
	container=>'mp4',
	pixel => '720',
	ypixel => '576',
	anamorph=>'--loose-anamorphic',
	modulus=>'8',
        quality=>'HQ',
	audiotracks=>'all',
      },

TRANSFORMER => { shortname=>'TF101', name=>'Asus EeePC Transformer Profile ( Android 3.1 )',
		  resolution=> 'TF101',
		  container=>'mp4',
		  largefile=>'true',
		  anamorph=>'--loose-anamorphic',
		  pixel=>'1280',
		  ypixel=>'800',
		  modulus=>'16',
		  codec=>'-e x264',
		  audiotracks=>'all',
		  crop=>'auto',
		  quality=>'rf:20',
		  codecopts=>'-x mixed-refs=0:weightb=0:subq=7:ref=4:deblock=-2,-1:trellis=1:analyse=some',},

SDMKV => { shortname=>'SD-MKV',name=>'SD (480p) Profile with HQ Bitrate MKV Container',
	resolution=>'480p',
	container=>'mkv',
	pixel => '852',
	ypixel => '480',
	anamorph=>'--loose-anamorphic',
	modulus=>'8',
        quality=>'HQ',
	audiotracks=>'all',},
};

$profile->{'SD'}->{'codec'} = $profile->{'default'}->{'codec'};
$profile->{'SD'}->{'codecopts'} = $profile->{'default'}->{'codecopts'};
#
$profile->{'HD'}->{'codec'} = $profile->{'default'}->{'codec'};
$profile->{'HD'}->{'codecopts'} = $profile->{'default'}->{'codecopts'};
#
$profile->{'smallHD'}->{'codec'} = $profile->{'default'}->{'codec'};
$profile->{'smallHD'}->{'codecopts'} = $profile->{'default'}->{'codecopts'};

$profile->{'PAL'}->{'codec'} = $profile->{'default'}->{'codec'};
$profile->{'PAL'}->{'codecopts'} = $profile->{'default'}->{'codecopts'};

# hier neues profile (name) eintragen
$profile->{'default'}->{'profiles'} = 'SD HD smallHD PAL TRANSFORMER SDMKV';


sub getprofile {
my ($self,$args) = @_;
my $p = \$args->{'profile'};
my $dbg = \$args->{'debug'};
return ($profile->{${$p}});
}
sub prepareprofile {
my ($self,$args) = @_;
my $proccessvideodir = \$args->{'file'};
my $defaultprofile = \ $args->{'profile'};
my $hb_bin = \$args->{'hb_bin'};
my $nice = \$args->{'nice'};
my $setcpu = \$args->{'setcpu'};
my $config = \$args->{'config'};
my $dbg=\$args->{'debug'};
$self->message ({msg=>'read and prepare profile for transcode process',v=>'vvv',});
my $default = \$self->getprofile({profile=>${$defaultprofile},});

# get profile defaults
my $profiledefaults = \$self->getprofile({profile=>'default',});

my $xmlprofile = \$self->getfromxml({file=>"${$proccessvideodir}/vdrtranscode.xml",
				field=>'ALL',
				debug=>${$dbg},
				});



my $returndb = {
  nice=>${$nice},
  hb_bin=>${$hb_bin},
  setcpu=>${$setcpu},
  param_x => ${$xmlprofile}->{'pixel'},
  param_y => ${$xmlprofile}->{'ypixel'},
  container => ${$xmlprofile}->{'container'},
  dd_hd_sd => ${$xmlprofile}->{'dd_hg_sd'},
  quality => ${$xmlprofile}->{'quality'},
  name => ${$xmlprofile}->{'name'},
  audiotracks => ${$xmlprofile}->{'audiotracks'},
  codecopts => $profile->{'default'}->{'codecopts'},
  codec => $profile->{'default'}->{'codec'},
  modulus => ${$xmlprofile}->{'modulus'},
  container => ${$xmlprofile}->{'container'},
  AAC_Bitrate => ${$config}->{'AAC_Bitrate'},
  DRC => ${$config}->{'DRC'},
};


#<destination>
#<container>mp4</container>
#<dd_hd_sd>HD-smallHD</dd_hd_sd>
#<quality>HQ</quality>
#<audiotracks>all</audiotracks>
#</destination>
# werte von untenstehenden werten sind kbit

#UVHQ = 7000
#VHQ =  3700 
#HQ = 1200
#MQ = 800
#LQ = 600
#VLQ = 400

if ( ${$xmlprofile}->{'modulus'} ) {
      $returndb->{'modulus'} = ${$xmlprofile}->{'modulus'};
}

# if quality setting not digit try to use bitrate from standard qualitys
if ( ${$xmlprofile}->{'quality'} ) {
  given ( ${$xmlprofile}->{'quality'} ) {
  # LQ for Webencoding -> sets maximum width of picture to 480 , disables anamorph encoding, sets AAC Rate to 96
    when ( /^600$/smx ) {

      $returndb->{'param_x'} = SECHSVIERNULL;
      $returndb->{'param_anamorph'} = undef ;
      $returndb->{'AAC_Bitrate'} = '96';
    }
    when ( /^400$/smx ) {
    	$returndb->{'param_x'} = VIERACHTNULL;
	$returndb->{'param_anamorph'} = undef ;
	$returndb->{'AAC_Bitrate'} = '96';
    }
    when ( /^(?:LQ|MQ|HQ)$/smx ) {
      if ( ( ${$config}->{'recalculate_bitrate'} ) and ( ${$xmlprofile}->{'pixel'} ) and ( ${$xmlprofile}->{'ypixel'} ) ) {
	my $bitrate = \$self->_calculate_bitrate({ x=>${$xmlprofile}->{'pixel'},
						    y=>${$xmlprofile}->{'ypixel'},
						    q=>${$xmlprofile}->{'quality'},
						    debug=>${$dbg},});
	$returndb->{'quality'} = ${$bitrate};
	
      } else {
	$returndb->{'quality'} = ${$profiledefaults}->{'quality'}->{ ${$xmlprofile}->{'quality'} };
      }
    }
    when ( /^(?:UVHQ|VHQ|VLQ)$/smx ) {
      $returndb->{'quality'} = ${$profiledefaults}->{'quality'}->{ ${$xmlprofile}->{'quality'} };
    }
    when ( /^\d{1,5}$/smx ) {
      $returndb->{'quality'} = ${$xmlprofile}->{'quality'};
    }
    when ( /^rf[:]\d{1,2}$/smx ) {
      $returndb->{'quality'} = ${$xmlprofile}->{'quality'};
    }
  } # end given
} # end if ${$xmlprofile}->{'quality'}


if ( ${$xmlprofile}->{'codecopts'} ) {
  $returndb->{'codecopts'} = ${$xmlprofile}->{'codecopts'} ;
}

# use x264 , instead ffmpeg , enable 2Pass and the x264 encoder options 
if ( ${$xmlprofile}->{'codec'} ) {
  $returndb->{'codec'} = ${$xmlprofile}->{'codec'};
}

if (  ${$xmlprofile}->{'container'} ) {
  $returndb->{'container'} = ${$xmlprofile}->{'container'};
}

if ( ${$config}->{'anamorph_encoding'} ) {
  $returndb->{'param_anamorph'} = '--loose-anamorphic' ;
} # enable anamorph_encoding

if ( ${$defaultprofile} !~ /^(?:SD|HD|smallHD)$/smx ) {
#  $returndb->{'codec'} = ${$xmlprofile}->{'codec'} ;
  $returndb->{'param_anamorph'} = ${$xmlprofile}->{'anamorph'};
  $self->message({msg=>'prepareprofile  use codec and anamorph settings from profile',v=>'v',}) ;
}

if (  ${$xmlprofile}->{'crop'} ) {
 $returndb->{'crop'} = ${$xmlprofile}->{'crop'};
}

if (  ${$xmlprofile}->{'largefile'} ) {
 $returndb->{'largefile'} = ${$xmlprofile}->{'largefile'};
}

return ($returndb);
}
sub _calculate_bitrate {
my ($self,$args) = @_;
my $x = \$args->{'x'};
my $y = \$args->{'y'};
my $q = \$args->{'q'};
my $dbg=\$args->{'debug'};
$self->message ({msg=>'recalulate bitrate by destination resolution',v=>'vvv',});
my $bitrate = ${$x} * ${$y} * $profile->{'default'}->{'codec_ratio'}->{'h264'} * $profile->{'default'}->{'quality_ratio'}->{ ${$q} } ;
$bitrate = sprintf '%.0f', $bitrate;

return ($bitrate);
}
1;
