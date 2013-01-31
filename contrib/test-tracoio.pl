#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use lib 'lib/';

use Traco::Tracoio;

my $io = Traco::Tracoio->new();

#$io->_get_files_in_dir({dir=>'/opt/video.00',});


my $index='/opt/video.00/Star_Trek/2012-06-03.20.13.7-0.rec/index';



my ($sta,$staf) = $io->_getoffset({frame=>'2270093473',index=>$index,vdrversion=>'1.7',debug=>'1',});
print Dumper $sta;
print Dumper $staf;

#my $frame=8*(2270093473-1);
#my $buffer = \$io->_readindex({index=>$index,frame=>$frame});
#print Dumper $buffer;

