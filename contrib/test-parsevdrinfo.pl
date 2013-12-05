#!/usr/bin/perl -w
use lib '../lib/';
use Traco::Traco ;
use Data::Dumper ;

my $dir ='/opt/video.00/1941_-_Wo,_bitte,_geht\'s_nach_Hollywood?/2013-10-11.02.22.10-0.rec';


my $traco = Traco::Traco->new();

my $vdrinfo = \$traco->parsevdrinfo({dir=>$dir,debug=>'1',});


print Dumper $vdrinfo;

