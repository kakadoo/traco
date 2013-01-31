use Traco::Traco;

my $a=Traco::Traco->new({debug=>'1',});



#my $dir ='/opt/video.00/Der_rosarote_Panther_2/2011-04-10.20.14.5-0.rec';
#$dir = '/opt/video.00/The_Rolling_Stones#3A_Live_at_the_Max/2010-12-31.19.55.50.99.rec';
#$dir = '/opt/video.00/Rockpalast/2010-06-21.01.09.51.99.rec';
$dir='/opt/video.00/Blues_Brothers/2011-07-17.02.19.9-0.rec';

my $src='';
my $dst="$dir/vdrtranscode.ts";

my $rc=\$a->combine_ts({source=>$dir,target=>$dst,vdrversion=>'1.7',debug=>'1',f=>'25',});

print "test ergebnis ${$rc}\n";

