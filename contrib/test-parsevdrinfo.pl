#!/usr/bin/perl -w
use Traco::Traco ;
use Data::Dumper ;

my $dir ='/opt/video.00/Fortress_2_-_Die_Festung/2011-05-05.23.49.6-0.rec';

my $vdrtranscode = Traco::Traco->new();

my $vdrinfo = \$vdrtranscode->parsevdrinfo({dir=>$dir,,debug=>'1',});


print Dumper $vdrinfo;

