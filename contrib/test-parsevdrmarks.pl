#!/usr/bin/perl -w
use Traco::Traco ;
use Data::Dumper ;


my $dir ='/opt/video.00/Fortress_2_-_Die_Festung/2011-05-05.23.49.6-0.rec';
#my $dir = '/opt/video.00/The_Rolling_Stones#3A_Live_at_the_Max/2010-12-31.19.55.50.99.rec';


my $vdrtranscode = Traco::Traco->new();




my $vdrmarks = \$vdrtranscode->parsevdrmarks({dir=>$dir,,debug=>'1',});


print Dumper $vdrmarks;

