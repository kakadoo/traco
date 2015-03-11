#!/usr/bin/perl -w
use lib '../lib/';
use Traco::Traco ;
use Data::Dumper ;

my $file = '/opt/video.00';
my $vdrtranscode = Traco::Traco->new();


my @list = \$vdrtranscode->getfilelist({dir=>'/opt/video.00', skiplinks=>'true',debug=>'true', fs => 'nfs'});

print Dumper @list;

#foreach (@list) {
#if (${$_} =~ /xml/) {
#	print "${$_}\n";
#}
#}

