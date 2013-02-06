package Traco::Tracoxml;
# $Revision: 00001 $
# $Source: /home/glaess/vdr/traco/Tracoxml.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use IPC::Open3 'open3';
use feature qw/switch/;
use File::Basename;
#use Data::Dumper;
use constant {SECHSNULLNULL => '600', NEUN => '9',};

use Sys::Syslog qw/:DEFAULT setlogsock/;

require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);
@EXPORT_OK = qw(changexmlfile _createxmlfile _add_profile getfromxml createvdrtranscodexml);

$VERSION = '0.21';

#
# 0.01 inital version
# 0.02 add tag <frames> to createxmlfile
# 0.19 fix return of default in getfromxmlfile 
# 0.20 fix pattern matching getfromxml default
# 0.21 add _add_profile 

sub new {
	my ($class,$args) = @_;
	my $self = {};
	$class = ref($class) || $class;
	my $d = \$args->{'debug'} ;
	$self->{'debug'} = ${$d};
	if (${$d}) { print {*STDOUT} "$PROGRAM_NAME | new | uid = $UID | debug = ${$d}\n" or croak $ERRNO; }
	bless $self,$class;
	return $self;
} # end sub new

sub createvdrtranscodexml {
my ($self,$args) = @_;
my $videopath=\$args->{'dir'};
my $dbg=\$args->{'debug'};
my $profile=\$args->{'profile'};
my $returnline = q{};

$self->message ({msg=>"vdrtranscode.xml not exist , create in ${$videopath}",v=>'v',});
my $vdrinfocontent = \$self->parsevdrinfo({dir=>${$videopath},debug=>${$dbg},});
if ( ${$vdrinfocontent} ) {
  my $rc = \$self->_createxmlfile({dir=>${$videopath},
				    debug=>${$dbg},
				    vdrinfo=>${$vdrinfocontent},
				    profile=>${$profile},});
      if (${$rc} eq 'recording') {
	$returnline ="createvdrtranscodexml: still ${$rc}";
      } else {
	$self->message ({msg=>"create ${$videopath}/vdrtranscode.xml done",});
	$returnline = ${$rc};
      }
    }
return ($returnline);
}

sub changexmlfile {
my ($self,$args) = @_;
my $xmlfile = \$args->{'file'};
my $action = \$args->{'action'}; # can be add or change
my $field = \$args->{'field'};
my $chto = \$args->{'to'};
#my $block = \$args->{'block'};
my $content = \$args->{'content'} ;
my $dbg = \$args->{'debug'};
if ( not ( -e ${$xmlfile} ) ) { return ('xmlfile_not_found'); }
my $dir = dirname ${$xmlfile};
my $rc=q{};

given (${$action}) {
  when ( /^change$/smx ) {
   $rc=\$self->_support_change_xmlfile({file=>${$xmlfile},field=>${$field},to=>${$chto},debug=>${$dbg},});
  }
  when ( /^add$/smx ) {
   $rc=\$self->_support_add_xmlfile({file=>${$xmlfile},field=>${$field},content=>${$content},debug=>${$dbg},});
  }
} # end given action
return (${$rc});
} # end sub

sub _support_add_xmlfile {
my ($self,$args) = @_;
my $xmlfile = \$args->{'file'};
my $content = \$args->{'content'};
my $field = \$args->{'field'};
my $dbg = \$args->{'debug'};
#my $block = \$args->{'block'};
my $returnline = 'done';
my @check = ();

my $xmlcontent = \$self->readfile({file=>${$xmlfile},});
if ( ${$xmlcontent}->{'returncode'} !~ /[_]done$/smx ) { return ('missing_xml_file_for_add') ; }
#@{ ${$lines}->{'returndata'} }

my @existfield = grep { /\<(${$field})\>/smx } @{ ${$xmlcontent}->{'returndata'} } ;

if ($#existfield < 0) {
# now add the new lines 
# parse 
# container = [mp4|m4v|mkv] 
# dd_hd_sd = [DD|noDD|HD-HD|HD-smallHD] 
# quality = [VHQ|HQ|MQ]
given (${$field}) {
  when ( /^w_x_h$/smx ) {
    push @{ ${$xmlcontent}->{'returndata'} } ,"<w_x_h>${$content}</w_x_h>";
  }
  when ( /^transcode_with_fps$/smx ) {
    push @{ ${$xmlcontent}->{'returndata'} } ,"<transcode_with_fps>${$content}</transcode_with_fps>";
  }
  when ( /^container$/smx ) {
    if ( ${$content} =~ /(?:mp4|m4v|mkv)/smx ) {
      push @{ ${$xmlcontent}->{'returndata'} } ,"<container>${$content}</container>";
    }
  }
  when ( /^dd_hd_sd$/smx ) {
      if ( ${$content} =~ /(?:DD|noDD|HD-HD|HD-smallHD)/smx ) {
	push @{ ${$xmlcontent}->{'returndata'} } ,"<dd_hd_sd>${$content}</dd_hd_sd>";
      }
    }
  when ( /^quality$/smx ) {
      if ( ${$content} =~ /(?:VHQ|HQ|MQ)/smx ) {
	push @{ ${$xmlcontent}->{'returndata'} } ,"<quality>${$content}</quality>";
      }
    }
    when ( /^audiotracks$/smx ) {
     if ( ${$content} =~ /(?:first|all)/smx ) {
      push @{ ${$xmlcontent}->{'returndata'} } ,"<audiotracks>${$content}</audiotracks>";
     }
    }
    when (/^block-start$/smx ) {
      push @{ ${$xmlcontent}->{'returndata'} } ,"<${$content}>";
    }
    when (/^block-stop$/smx ) {
      push @{ ${$xmlcontent}->{'returndata'} } ,"</${$content}>";
    }
    when (/^totalframes$/smx ) {
      push @{ ${$xmlcontent}->{'returndata'} } ,"<totalframes>${$content}</totalframes>";
    }
}
} else {
# if field exists replace it with new one
  for my $z ( 0 .. $#{ ${$xmlcontent}->{'returndata'} } ) {
    if ( ${$xmlcontent}->{'returndata'}[$z] =~ /(${$field})/smx ) {
      ${$xmlcontent}->{'returndata'}[$z]  = "<${$field}>${$content}</${$field}>";
    }
    $z++;
  }
}
my $wrrc = \$self->writefile({file=>${$xmlfile},content=>\@{ ${$xmlcontent}->{'returndata'} },});

undef $xmlcontent;
return ($returnline);
}


sub _support_change_xmlfile {
my ($self,$args) = @_;
my $xmlfile = \$args->{'file'};
my $field = \$args->{'field'};
my $chto = \$args->{'to'};
my $dbg = \$args->{'debug'};

# if not an allowed change field 
if ( ${$field} !~ /^(?:status|files|quality|container|audiotracks)$/smx )  {
    return ('wrong_field_for_change');
}
my $xmlcontent = \$self->readfile({file=>${$xmlfile},});
if ( ${$xmlcontent}->{'returncode'} !~ /[_]done$/smx ) { return ('missing_xml_file_for_change') ; }

my $oldfield=${$field};
my $newfield="<${$field}>${$chto}</${$field}>";
for my $x (0 .. $#{ ${$xmlcontent}->{'returndata'} } ) {
  if (${$xmlcontent}->{'returndata'}[$x] =~ /\<$oldfield\>/smx) {
    ${$xmlcontent}->{'returndata'}[$x] = $newfield;
  }
}

my $wrrc = \$self->writefile({file=>${$xmlfile},content=>\@{ ${$xmlcontent}->{'returndata'} },});

undef $xmlcontent;
return ('done');
}

sub _createxmlfile  {
my ($self,$args) = @_;
my $xmlpath = \$args->{'dir'};
my $vdrinfo = \$args->{'vdrinfo'};
my $dbg = \$args->{'debug'};
my $profile=\$args->{'profile'};

my @writecontent = ();
my $z=0;
my $streamfiles = q{};
# check first if recording finished
my $mytime = time ;
# end time based on epoch time 
# caculate vdrinfo startime + vdrinfo duration + 10 min
my $endtime = ${$vdrinfo}->{'starttime'} + ${$vdrinfo}->{'duration'} + SECHSNULLNULL ;
if ($mytime < $endtime ) { return ('recording') ; };


# write first status
push @writecontent,'<status>offline</status>';
# open bock <vdrinfo>
push @writecontent,'<vdrinfo>';
if ( ${$vdrinfo}->{'aspect'} ) { push @writecontent,"<aspect>${$vdrinfo}->{'aspect'}</aspect>"; }
if ( ${$vdrinfo}->{'title'} ) { push @writecontent,"<title>${$vdrinfo}->{'title'}</title>"; }
if ( ${$vdrinfo}->{'HD'} ) { push @writecontent,"<hd>${$vdrinfo}->{'HD'}</hd>"; }
if ( ${$vdrinfo}->{'frames'} ) { push @writecontent,"<frames>${$vdrinfo}->{'frames'}</frames>"; }
if ( ${$vdrinfo}->{'starttime'} ) { push @writecontent ,"<starttime>${$vdrinfo}->{'starttime'}</starttime>"; }
if ( $endtime ) { push @writecontent , "<endtime>$endtime</endtime>"; }

for my $z (0 ... NEUN) {
  my $track =  "audiotrack$z";
  if ( ${$vdrinfo}->{$track} ) { push @writecontent,"<src_audio track=\"$z\">${$vdrinfo}->{$track}</src_audio>"; }
}
# close block <vdrinfo>
push @writecontent,'</vdrinfo>';

# check for .ts files
my @tsfiles = ();
if ( -e "${$xmlpath}/vdrtranscode.ts" )  {
  push @tsfiles , "${$xmlpath}/vdrtranscode.ts" ;
} else {
  @tsfiles = $self->_get_files_in_dir ({dir=>${$xmlpath},pattern=>'*.ts',});
}
# if no .ts files check for .vdr files
if ( $#tsfiles < 0 ) {
  @tsfiles = $self->_get_files_in_dir ({dir=>${$xmlpath},pattern=>'[0-9]*.vdr',});
}

if ($#tsfiles >= 0 ) {
  for my $ts (@tsfiles) {
    my $finame = basename $ts;
    $streamfiles = "$streamfiles $finame";
  }
 }
$streamfiles =~ s/^\s//smx ; # remove traling space
# add to writecontent in xml style
if ($streamfiles) { push @writecontent,"<files>$streamfiles</files>"; }
#
for my $w (@writecontent) {
   $self->message({msg=>"_createxmlfile | write | $w" , debug=>${$dbg},v=>'vvv', });
}

#my $profiledefaults=\$self->getprofile({profile=>'default'});
#my $p=\$self->getprofile({profile=>${$profile},debug=>${$dbg},});
#my @keys = split /\s/smx , ${$profiledefaults}->{'keys'};
#if ( ${$p}->{'shortname'} ) {
#  push @writecontent,"<profile name=\"${$p}->{'shortname'}\">";
#  for my $k (@keys) {
#      if ($k =~ /^shortname$/smx ) { next ; }
#      if ( ( $k =~ /^quality$/smx ) and ( ${$p}->{$k} =~ /(?:UVHQ|VHQ|HQ|MQ|LQ|VLQ)/smx ) )  {
#	push @writecontent,"<$k>${$profiledefaults}->{$k}->{${$p}->{'quality'}}</$k>";
#      } else {
#	push @writecontent,"<$k>${$p}->{$k}</$k>";
#      }
#    }
#  }
#push @writecontent,'</profile>';
my $wrrc = \$self->writefile({file=>"${$xmlpath}/vdrtranscode.xml",content=>\@writecontent,debug=>${$dbg}});
$self->_add_profile({profile=>${$profile},dir=>${$xmlpath},debug=>${$dbg},});

return ('_createxmlfile_done');
}

sub _add_profile {
my ($self,$args) = @_;
my $dbg = \$args->{'debug'};
my $profile=\$args->{'profile'};
my $xmlpath = \$args->{'dir'};

my @writecontent ;

my $profiledefaults=\$self->getprofile({profile=>'default'});
my $p=\$self->getprofile({profile=>${$profile},debug=>${$dbg},});
my @keys = split /\s/smx , ${$profiledefaults}->{'keys'};
if ( ${$p}->{'shortname'} ) {
  push @writecontent,"<profile name=\"${$p}->{'shortname'}\">";
  for my $k (@keys) {
      if ( not ( ${$p}->{$k} ) ) { next ; }
      if ($k =~ /^shortname$/smx ) { next ; }
      if ( ( $k =~ /^quality$/smx ) and ( ${$p}->{$k} =~ /(?:UVHQ|VHQ|HQ|MQ|LQ|VLQ)/smx ) )  {
	push @writecontent,"<$k>${$profiledefaults}->{$k}->{${$p}->{'quality'}}</$k>";
      } else {
	push @writecontent,"<$k>${$p}->{$k}</$k>";
      }
    }
  }
push @writecontent,'</profile>';

my $wrrc = \$self->writefile({file=>"${$xmlpath}/vdrtranscode.xml",content=>\@writecontent,options=>'>>',debug=>${$dbg},});

return ('_addprofile_done');
}
sub getfromxml {
my ($self,$args) = @_;
my $file = \$args->{'file'};
my $field = \$args->{'field'};
my $block = \$args->{'block'} ;
my $dbg = \$args->{'debug'};
my $returnline = {};

if ( ( not ( $field ) ) and ( not ( ${$file} ) ) ) { return ('missing_option_getfromxml'); }

my $content = \$self->readfile({file=>${$file},});

#print Dumper $content;
if ( ${$content}->{'returncode'} !~ /[_]done$/smx ) { return ('missing_xml_file_to_read') ; }


if ( ${$block} ) {
  for my $l (@{ ${$content}->{'returndata'} } ) {
    if ($l =~ /\<(${$block})\>/smx .. $l =~ /[<]\/(${$block})[>]/smx ) {
    my ($key,$value);
	if ( $l =~ /\<(${$field})\>/smx ) {
	  ($key,$value)= $l =~ /[<](\w+)[>](.+)[<]\/\w+[>]/smx;
	}
	if ($key) {
	  $returnline->{$key} = $value;
	}
    }
  }
  return ($returnline);
}

given ( ${$field} ) {
  when ( /^ALL$/smx ) {
    for my $l (@{ ${$content}->{'returndata'} } ) {
      my ($key,$value)= $l =~ /[<](\w+)[>](.+)[<]\/\w+[>]/smx;
      if ($key) {
	$returnline->{$key} = $value;
      }
    }
  }
  default {
    my @result = grep { /\<(${$field})\>/smx } @{ ${$content}->{'returndata'} } ;

    if ($#result == 0) {
      my ($key,$value) = $result[0] =~ /[<](\w+)[>](.+)[<]\/\w+[>]/smx;
      $returnline = $value;
    } else {
      $returnline = undef;
    }
  }
}

undef $content;
return ($returnline);
}



1;

__END__

=head1 NAME

  Traco::Tracoxml

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


