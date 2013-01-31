#!/usr/bin/perl -w
use Traco::Traco ;
use Data::Dumper ;

my $file = '/opt/video.00/Rockpalast/2010-06-21.01.09.51.99.rec/vdrtranscode.ts';

my $vdrtranscode = Traco::Traco->new();

my $handbrake = \$vdrtranscode->handbrakeanalyse({file=>$file,
        nice=>'20',
        handbrake=>'/usr/bin/HandBrakeCLI',
        debug=>'0',
        kbps=>'true',
        fpstype=>'vdr',
        audiotrack=>'all',
        drc=>'2.5',
        aac_bitrate=>'128',
        });


print Dumper $handbrake;

