use lib 'lib/';
use Traco::Traco;

my $a=Traco::Traco->new({debug=>'1',});



my $dir = '/opt/video.00/Bernhard_Victor_Christoph_Carl_von_Bülow/2011-08-23.22.00.3-0.rec';
my $src='';

my $rc=\$a->_joinfiles({dir=>$dir,files=>'00001.ts 00002.ts',debug=>'1',f=>'25',});

print "test ergebnis ${$rc}\n";

