#!/usr/bin/perl -w
use strict;
use warnings;
use Traco::Traco;
use Data::Dumper;

my $p = Traco::Traco->new();
my $cfg=\$p->parseconfig({config=>'/etc/vdr/traco.conf',});

#print Dumper ${$cfg};

my $prof=$p->getprofile({profile=>'TRANSFORMER',});
my $file = '/opt/video.00/Indiana_Jones_und_der_letzte_Kreuzzug/2011-11-13.15.34.7-0.rec';
#print Dumper $prof;


my $test = $p->prepareprofile({file=>$file,hb_bin=>'/usr/bin/HandBrakeCli',nice=>'/usr/bin/nice',setcpu=>'1',debug=>'true',profile=>$prof,config=>${$cfg},});

print Dumper $test;

