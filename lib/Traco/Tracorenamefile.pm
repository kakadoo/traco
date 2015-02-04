package Traco::Tracorenamefile;
# $Revision: 00001 $
# $Source: /home/glaess/perl/vdr/traco/Tracorenamefile.pm $
# $Id: Holger Glaess $
use strict;
use warnings;
#use Data::Dumper;
use File::Copy ;
use English '-no_match_vars';
use Carp;
use feature qw/switch/;
no if $] >= 5.018, warnings => "experimental";
require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);
use base qw(Exporter);

@EXPORT_OK = qw(rename_and_store);

$VERSION = '0.04';

#
# 0.01 inital version
#
# fileformat macros
# %t title
# %d day 1-31
# %m month 1-12
# %y year 20xx ( should be )
# %ho hour
# %mi minute
# %se second
# %vr videoformat ( 480p.720p1080x , resolution )
# %vx x pixel
# %vy y pixel
# %fps frames per second
# %c container

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


sub rename_and_store {
my ($self,$args) = @_;
my $d = \$args->{'dir'};
my $dbg = \$args->{'debug'};
my $format = \$args->{'filenameformat'};
my $returndb = '_rename_and_store_done';
my $dstdir=\$args->{'destination'};
my $dir = ${$d};
my $store = \$args->{'store'}; # copy or move
my $xml = \$args->{'xml'};
my $t = \$args->{'tmpfile'};
my $tmpfile = ${$t};

if ( not ( ${$store} ) ) { ${$store} = 'move'; }
if ( not ( ${$format} ) ) { return ('rename_and_store_missing_format'); }
if ( not ( ${$dstdir} ) ) { return ('rename_and_store_missing_destination_directory'); }
my $filename = ${$format};



my $vdrinfo = \$self->getfromxml({file=>"$dir/${$xml}",field=>'ALL',debug=>${$dbg},});
my $x = ${$vdrinfo}->{'pixel'};
my $y = ${$vdrinfo}->{'ypixel'};
my $fps = ${$vdrinfo}->{'frames'};
my $title = ${$vdrinfo}->{'title'};
my $container = ${$vdrinfo}->{'container'};
my $res = ${$vdrinfo}->{'resolution'};
my $destinationfile = q{};

my $tida = \$self->_preparedtime({timeformat=>3,});
my ($mday,$mo,$year,$hour,$min,$sec) = split /\s/smx , ${$tida};


if ( $filename =~ /[%]y/smx ) { $filename =~ s/[%]y/$year/smx ; }
if ( $filename =~ /[%]m/smx ) { $filename =~ s/[%]m/$mo/smx ; }
if ( $filename =~ /[%]d/smx ) { $filename =~ s/[%]d/$mday/smx ; }
if ( $filename =~ /[%]t/smx ) { $filename =~ s/[%]t/$title/smx ; }
if ( $filename =~ /[%]ho/smx ) { $filename =~ s/[%]ho/$hour/smx ; }
if ( $filename =~ /[%]mi/smx ) { $filename =~ s/[%]mi/$min/smx ; }
if ( $filename =~ /[%]se/smx ) { $filename =~ s/[%]se/$sec/smx ; }
if ( $filename =~ /[%]y/smx ) { $filename =~ s/[%]y/$year/smx ; }
if ( $filename =~ /[%]vr/smx ) { $filename =~ s/[%]vr/$res/smx ; }
if ( $filename =~ /[%]fps/smx ) { $filename =~ s/[%]fps/$fps/smx ; }
if ( $filename =~ /[%]c/smx ) { $filename =~ s/[%]c/$container/smx ; }
if ( $filename =~ /[%]vx/smx ) { $filename =~ s/[%]vx/$x/smx ; }
if ( $filename =~ /[%]vy/smx ) { $filename =~ s/[%]vy/$y/smx ; }

if ( ( $filename =~ /[%]e/smx ) && ( ${$vdrinfo}->{'episode'} ) ) {
	my $episode = ${$vdrinfo}->{'episode'} ;
	$filename =~ s/[%]e/$episode/smx ; 
} elsif ( $filename =~ /[%]e/smx ) {
	$filename =~ s/[%]e//smx 
}

$self->message({msg=>"_rename_and_store | $dir | build filename $filename",v=>'vvv',});

my $sourcefile = q{};
my @flist = \$self->_get_files_in_dir({dir=>$dir,});

#foreach my $f (@flist) {
#  if (${$f} =~ /$tmpfile[.](?:mp4|m4v|mkv)/smx ) {
#    $sourcefile = ${$f};
#  }
#}

map {
  if (${$_} =~ /$tmpfile[.](?:mp4|m4v|mkv)/smx ) {
    $sourcefile = ${$_};
  }
} @flist;


$self->message({msg=>"_rename_and_store | sourcefile  $sourcefile",v=>'vvv',});

$self->message({msg=>"_rename_and_store | copy $sourcefile to ${$dstdir}/$filename",v=>'v',});
# a slash is not allowed in filename, we replace it with a dash
$filename =~ s/\//\-/gmisx;
my $z=1;
while ( -e "${$dstdir}/$filename" ) {
  $filename = "$filename($z)";
  $z++;
}

given ( ${$store} ) {
  when ( /^copy$/smx ) {
    copy $sourcefile,"${$dstdir}/$filename" or croak "[rename_and_store] error $ERRNO\n";
  }
  when ( /^move$/smx ) {
    move $sourcefile,"${$dstdir}/$filename" or croak "[rename_and_store] error $ERRNO\n";
  }
}

return ($returndb);
} # end sub rename_and_store
1;
