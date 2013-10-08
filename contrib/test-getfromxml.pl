#!/usr/bin/perl -w
use lib '../lib';
use Traco::Traco ;
use Data::Dumper ;

my $dir ='/opt/video.00/Queen:_Hungarian_Rhapsody_-_Live_in_Budapest/2013-09-14.20.13.21-0.rec';

my $vdrtranscode = Traco::Traco->new();

my $vdrinfo = \$vdrtranscode->getfromxml({file=>"$dir/traco.xml",block=>'vdrinfo',field=>'frames',debug=>'1',});


print Dumper $vdrinfo;

