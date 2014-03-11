#!/usr/bin/perl -w
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/usr/local/bin/tracoadm.pl $
# $Id: Holger Glaess $
# $HeadURL www.glaessixs.de/projekte/vdrtranscode $ 
# $Date 22/06/2011 $

#use File::Basename ;
use strict;
use warnings;
use Carp;
use English '-no_match_vars';
use lib 'lib/';
use Traco::Traco ;
use Traco::Config ;
# now feature from 5.10
use feature qw/switch/;
#use Data::Dumper;

our $VERSION = '0.06';

# 0.03 fix delete
# 0.04 no use of indir form config anymore.
# 0.05 changes for usage Config.pm
my @options = @ARGV;
my $z=0;
my @transcodeoptions = ();
my $admenv = {};
#$admenv->{'configfile'} = '/etc/vdr/traco.conf'; # set default
#handle_configfile (@options);
#handle_profile_option (@options);

my $dstpath = pop @options;

while ($#options >= $z) {
  given ($options[$z]) {
    when ( /^audiotrack$/smx ) {
      my $a=$z+1;
      $admenv->{'audiotrack'} = $options[$a];
      $z++;
    }
    when ( /^container$/smx ) {
      my $a=$z+1;
      $admenv->{'container'} = $options[$a];
      $z++;
    }
    when ( /^show$/smx ) {
      my $a=$z+1;
      $admenv->{'show'} = $options[$a];
      $z++;
    }
    when ( /^quality$/smx ) {
      my $a=$z+1;
      $admenv->{'quality'} = $options[$a];
      $z++;
    }
    when ( /^status$/smx ) {
      my $a=$z+1;
      $admenv->{'status'} = $options[$a];
      $z++;
    }
    when ( /^delete$/smx ) {
      my $a=$z+1;
      $admenv->{'delete'} = $options[$a];
      $z++;
    }
    when ( /^[-]d$/smx ) {
      $admenv->{'debug_flag'}=1;
    }
    when ( /^[-]c$/smx ) {
      my $a = $z+1;
      $admenv->{'configfile'} = $options[$a];
    }
    when (/^[-][-]help$/smx ) {
      _myhelp ();
      leave ('_done');
    }
    when ( /^profile$/smx ) {
      my $a=$z+1;
      $admenv->{'profile'} = $options[$a];
      $z++;
    }
  } # end given
      $z++;
} # end while options;


my $traco=Traco::Traco->new({debug=>$admenv->{'debug_flag'},});
my $config = Traco::Config->new ();

#print Dumper $config ;
if ( ( defined $admenv->{'configfile'} ) and ( -e $admenv->{'configfile'} )) {
  $config->parseconfig({config=>$admenv->{'configfile'},debug=>$admenv->{'debug_flag'},});
}
# else {
#  print {*STDOUT} "missing $admenv->{'configfile'} exit $PROGRAM_NAME\n" or croak $ERRNO;
#  exit 1;
#}

my $profiledefaults=\$traco->getprofile({profile=>'default',});

set_user ();

#my @tmp = reverse @options
#my $workdir = $traco->preparepath({path=>$tmp[0],});
my $workdir = $traco->preparepath({path=>$dstpath,});
#undef @tmp;
if ( ( not ( defined $workdir ) ) or ( $#options < 0 ) ) {
  print {*STDOUT} "missing path ! or options try --help\n" or croak $ERRNO;
  leave ('_error');
}

#print Dumper $admenv;

if ( $admenv->{'status'} ) {
    my $rc=\get_set_status ('status',$admenv->{'status'},$workdir);
    leave ( ${$rc} );
}

if ( $admenv->{'profile'} ) {
  my $rc = \create_new_profile($admenv->{'profile'});
  leave ( ${$rc} );
}

if  ( $admenv->{'audiotrack'} ) {
  my $rc;
  if ( $admenv->{'audiotrack'} =~ /^(?:first|all)$/smx ) {
    $rc = \get_set_status ('audiotrack',$admenv->{'audiotrack'},$workdir);
    print {*STDOUT} "get_set_status_${$rc}\n" or croak $ERRNO;
  }
  leave (${$rc}) ;
}
if  ( $admenv->{'container'} ) {
my $rc;
  if ( $admenv->{'container'} =~ /^(?:mp4|mkv|m4v)$/smx ) {
    $rc = \get_set_status ('container',$admenv->{'container'},$workdir);
    print {*STDOUT} "get_set_status_${$rc}\n" or croak $ERRNO;
  }
  leave (${$rc}) ;
}

if ( $admenv->{'show'} ) {
  my $rc;
  if ( $admenv->{'show'} =~ /^profiles$/smx ) {
   $rc = \show_profiles();
  } else {
   $rc = \showxml ({dir=>$workdir,show=>$admenv->{'show'},});
   print {*STDOUT} "showxml_${$rc}\n" or croak $ERRNO;
  }
  leave (${$rc}) ;
}

if  ( $admenv->{'quality'} ) {
  my $rc=\change_quality ($admenv->{'quality'});
  leave (${$rc}) ;
}

if ( $admenv->{'delete'} ) {
  if ( unlink "$workdir/$admenv->{'delete'}" ) {
    print {*STDOUT} "delete_$workdir\/$admenv->{'delete'}\n" or croak $ERRNO;
  }
  leave('_done');
}


sub handle_configfile {
my @opts = @_;
my @configfileoption = grep { /[-]c/smx } @opts;
if ( $#configfileoption >= 0 ) {
  for my $o (0 .. $#opts ) {
    if ( $opts[$o] =~ /^[-]c$/smx ) {
      my $a = $o+1;
      $admenv->{'configfile'} = $opts[$a];
    }
  } 
}
return ('handle_configfile_done');
}

sub change_quality {
my $value=shift;
  #my @qual = qw(UVHQ VHQ HQ MQ LQ VLQ);
  #my @setup = grep { /^$value$/smx } @qual;

  given ($value) {
    when ( /^(?:UVHQ|VHQ|HQ|MQ|LQ|VLQ)$/smx ) {
      $admenv->{'quality'} = ${$profiledefaults}->{'quality'}->{$value};
    }
    when ( /^\d{2,5}$/smx ) {
      $admenv->{'quality'} = $value;
    }
  }

  my $rc = \get_set_status ('quality',$admenv->{'quality'},$workdir);
  print {*STDOUT} "get_set_quality_${$rc}\n" or croak $ERRNO;
return ( ${$rc} );
}

sub leave {
my $rc = shift;
  if ( not ( $rc ) ) {
	print {*STDOUT} "tracoadm exit with code 1\n"  or croak $ERRNO;
	exit 1;
  } else {
	print {*STDOUT} "tracoadm exit with $rc\n" or croak $ERRNO;
	exit 0;
  }
  if ( $rc =~ /\_done$/smx ) {
	print {*STDOUT} "tracoadm exit with code 0\n" or croak $ERRNO;
	exit 0;
  } #else { 
#	exit 1;
#  }
return ('leave_done');
}

sub show_profiles {
 my @prof = split /\s/smx , ${$profiledefaults}->{'profiles'};
 map {
  print {*STDOUT} "profile available $_\n" or crok $ERRNO;
 } @prof;
return ('show_profiles_done');
}

sub create_new_profile {
my $newprofile = shift;
# check first if profile exist

my @prof = split /\s/smx , ${$profiledefaults}->{'profiles'};
my $profileok = 'false';
for my $p (@prof) {
  if ( $p =~ /$newprofile/smx ) { $profileok='true'; }
}

if ( $profileok eq 'true' ) {
my $rc = \$traco->createxml({dir=>$workdir,
					  debug=>$config->{'debug_createvdrtranscodexml'},
					  profile=>$newprofile,
					  xml=>$config->{'traco_xml'},
					  ts=>$config->{'traco_ts'},
					});
print {*STDOUT} "create new xml file with profile $newprofile status_${$rc}\n" or croak $ERRNO;
}
return ('create_new_profile_done');
}
sub set_user {
#print Dumper $config;

if ( ( $config->{'vdr_user'} ) and ( getpwnam $config->{'vdr_user'} ) ) {
  my $vdruid = getpwnam $config->{'vdr_user'};
  $EUID = $vdruid;
  $UID = $vdruid;
} else {

  print {*STDOUT} "WARNING: missing or wrong vdr_user in traco config or system passwd\n" or croak $ERRNO;
}
return ('setup_user_done');
}

sub showxml {
my $opts=shift;
my $dir=$opts->{'dir'};
my $xml = $traco->getfromxml({file=>"$dir/$config->{'traco_xml'}",field=>'ALL',});
if ( $opts->{'show'} ) {
  given ( $opts->{'show'} ) {
    when ( /^status$/smx ) {
      print {*STDOUT} $xml->{'status'},"\n" or croak $ERRNO;
    }
    when ( /^profile$/smx ) {
      print {*STDOUT} "name\t\t$xml->{'name'} \n" or croak $ERRNO;
      print {*STDOUT} "resolution\t$xml->{'resolution'} \n" or croak $ERRNO;
      print {*STDOUT} "container\t$xml->{'container'}\n" or croak $ERRNO;
      print {*STDOUT} "pixel\t\t$xml->{'pixel'}\n" or croak $ERRNO;
      print {*STDOUT} "anamorph\t$xml->{'anamorph'}\n" or croak $ERRNO;
      print {*STDOUT} "modulus\t\t$xml->{'modulus'}\n" or croak $ERRNO;
      print {*STDOUT} "quality\t\t$xml->{'quality'}\n" or croak $ERRNO;
      print {*STDOUT} "audiotracks\t$xml->{'audiotracks'}\n" or croak $ERRNO;
      print {*STDOUT} "codec\t\t$xml->{'codec'}\n" or croak $ERRNO;
      print {*STDOUT} "codecopts\t$xml->{'codecopts'}\n" or croak $ERRNO;
    }
  }
}
leave ('_done');
return ();
}
sub get_set_status {
my $option = shift ;
my $value = shift ;
my $mypath = shift ;
my $status = \$traco->getfromxml({file=>"$mypath/$config->{'traco_xml'}",field=>'status',});
my $returnline;
if ( not ( $mypath ) ) { return ('missing_path'); }
if ( ${$status} =~ /^proccessing$/smx ) { return ("$mypath in progress"); }

given ($option) {
  when ( $value =~ qr/^(?:ready|online|offline|cutfiles|joinfiles|prepare_traco_ts)$/smx ) {
    my $rc=\$traco->changexmlfile
      ({file=>"$mypath/$config->{'traco_xml'}",
	action=>'change',
	field=>'status',
	to=>$value,
	debug=>$admenv->{'debug_flag'},
	});
    $returnline = ${$rc};
  }
  when  ( /^audiotrack$/smx ) {
    my $rc=\$traco->changexmlfile
      ({file=>"$mypath/$config->{'traco_xml'}",
	action=>'change',
	field=>'audiotracks',
	to=>$admenv->{'audiotrack'},
	debug=>$admenv->{'debug_flag'},
	});
    $returnline = ${$rc};
  }
  when  ( /^quality$/smx ) {
    my $rc=\$traco->changexmlfile
      ({file=>"$mypath/$config->{'traco_xml'}",
	action=>'change',
	field=>'quality',
	to=>$admenv->{'quality'},
	debug=>$admenv->{'debug_flag'},
	});
    $returnline = ${$rc};
  }
  when  ( /^container$/smx ) {
    my $rc=\$traco->changexmlfile
      ({file=>"$mypath/$config->{'traco_xml'}",
	action=>'change',
	field=>'container',
	to=>$admenv->{'container'},
	debug=>$admenv->{'debug_flag'},
	});
    $returnline = ${$rc};
  }
}
return ($returnline);
}

sub _myhelp {
  while (<DATA>) {
    print {*STDOUT} "$_\n" or croak $ERRNO;
  }
  return () ;
}

1;
__DATA__
tracoadm.pl 
audiotrack 
	    first or all
quality 
	UVHQ VHQ HQ MQ LQ VLQ or up to 5 digits 
container 
	  m4v , mkv , mp4 
status 
  offline , online , joinfiles , cutfiles , transcodedone , proccessing , ready , prepare_traco_ts
  /path/film dir

show 
      status profiles
