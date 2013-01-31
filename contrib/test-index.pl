#!/usr/bin/perl -w
use Data::Dumper;
use Readonly;
use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use Cwd;

my $dir = getcwd;
 
Readonly my $ACHT => 8;

my $frame = $ARGV[0];

my $buffer = q{};
my $startpos = $ACHT * $frame;
my $index="$dir/index";

print $index,"\n";

if ( not ( -e $index ) ) { exit 1; }

my $info = {};

$info->{'index_filesize'} = ( -s $index ) ;
$info->{'totalframes'} = ( $info->{'index_filesize'} / $ACHT) ;
$info->{'totalrecordingsek'} = ( $info->{'totalframes'} / 25 );
$info->{'totalrecordingmin'} = ( $info->{'index_filesize'} / 12000 ) ;

print Dumper $info;


  open my $INDEX, '<', $index or croak "Couldn't open $index $ERRNO\n";
      seek $INDEX, $startpos ,'0' ;
      read $INDEX, $buffer, 8;
  close $INDEX or croak "Couldn't close $index $ERRNO\n";



#my ($frameoffset,$frametype,$filenumber,undef) = unpack 'H2H2H2H2H2H2H2H2', $buffer;
#my ($frameoffset,undef,$independent,$filenumber) = unpack 'iccs', $buffer;
my ($frameoffset,$a,$independent,$filenumber) = unpack 'nsss', $buffer;

#my $frametype = unpack 'H2', $buffer;
print Dumper $frameoffset;
print Dumper $independent; # oder frametype
print Dumper $filenumber;

print hex $frameoffset," frameoffset \n";
#print hex $independent," independent / frametype \n";
print hex $filenumber," filenumber \n";

