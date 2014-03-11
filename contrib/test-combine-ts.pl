use lib '../lib';
use Traco::Traco;


my $a=Traco::Traco->new({debug=>'1',});



$dir='/opt/video.00/Robbie_Williams_-_Let\'s_swing_again!/2013-12-07.23.38.1-0.rec';

my $src='';
my $dst='traco.ts';

my $rc=\$a->combine_ts({source=>$dir,
			target=>$dst,
			vdrversion=>'1.7',
			debug=>'1',
			fpstype=>'vdr',
			nice=>'nice -n 20',
			handbrake=>'/usr/bin/HandBrakeCLI',
			marksfile=>"$dir/marks",
			xml => 'traco.xml',
			indexfile => 'index',
});

print "test ergebnis ${$rc}\n";

