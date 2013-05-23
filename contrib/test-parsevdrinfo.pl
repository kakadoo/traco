#!/usr/bin/perl -w
use lib 'lib/';
use Traco::Traco ;
use Data::Dumper ;

my $dir ='/opt/video.00/Der_Rote_Baron/2013-05-19.22.48.6-0.rec';

my $traco = Traco::Traco->new();

my $vdrinfo = \$traco->parsevdrinfo({dir=>$dir,debug=>'1',});


print Dumper $vdrinfo;

