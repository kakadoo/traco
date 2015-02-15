use lib '../lib/';
use Traco::Traco;
use Traco::Config;
use Data::Dumper;

my $a=Traco::Traco->new({debug=>'1',});
my $c=Traco::Config->new();

print $c->{'svdrpsend_flags'} . "\n";


#my $dir = '/opt/video.00/Robbie_Williams_-_Let\'s_swing_again!/2013-12-07.23.38.1-0.rec';
my $dir = '/opt/video.00/ZZ_Top\:_Live_at_Montreux/2015-01-01.02.13.17-0.rec';

my $src='';

my $rc=\$a->vdrcut({dir => $dir , xml=>'traco.xml',debug=>'1',svdrpsend_flags => $c->{'svdrpsend_flags'}, });

print Dumper ${$rc} ;

