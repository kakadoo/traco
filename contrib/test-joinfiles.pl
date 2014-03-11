use lib '../lib/';
use Traco::Traco;

my $a=Traco::Traco->new({debug=>'1',});



my $dir = '/opt/video.00/Robbie_Williams_-_Let\'s_swing_again!/2013-12-07.23.38.1-0.rec';
my $src='';

my $rc=\$a->_joinfiles({dir=>$dir,files=>'00001.ts 00002.ts 00003.ts 00004.ts',debug=>'1',destination=>"$dir/traco.ts"});

print "test ergebnis ${$rc}\n";

