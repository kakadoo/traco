#!/usr/bin/perl -w
use Traco::Traco ;
use Data::Dumper ;


my $dir ='/opt/video.00/Fortress_2_-_Die_Festung/2011-05-05.23.49.6-0.rec';
#my $dir = '/opt/video.00/WTCC_-_Tourenwagenweltmeisterschaft/2011-06-25.13.18.23-0.rec';
#my $dir = '/opt/video.00/The_Rolling_Stones#3A_Live_at_the_Max/2010-12-31.19.55.50.99.rec';



my $startframe = $ARGV[0];



my $vdrtranscode = Traco::Traco->new();

my ($sta,$staf) = \$vdrtranscode->_getoffset({frame=>$startframe,index=>"$dir/index",vdrversion=>'1.7',debug=>'1',});




print Dumper $sta;
print Dumper $staf;

