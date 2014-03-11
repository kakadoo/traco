#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;

use lib '../lib';
use Traco::Traco;


my $t = Traco::Traco->new();

my $a = '1';
my $dir = '/opt/video.00/Mel_Brooks\'_Spaceballs/2013-11-18.00.52.9-0.rec';


my ($q,$w) = $t->_get_filename_by_cutfilenumber({ dir=>$dir, fileno => $a });


print Dumper $q;


