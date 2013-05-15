#!/usr/bin/perl -w
use lib 'lib/';
use Traco::Traco ;
use Data::Dumper ;

#my $file = '/opt/video.00/Universal_Soldier/2011-06-25.23.54.5-0.rec/vdrtranscode.ts';
#my $file = '/opt/video.00/Avatar_-_Aufbruch_nach_Pandora/2012-04-08.20.13.5-0.rec/vdrtranscode.ts';

my $file = '/opt/video.00/Elton_John:_Live_at_Ibiza123_feat._Pnau/2012-12-31.11.28.34-0.rec/vdrtranscode.ts';

my $traco = Traco::Traco->new();

my $scan = \$traco->handbrakeanalyse({file=>$file,
        nice=>'20',
        handbrake=>'/usr/bin/HandBrakeCLI',
        debug=>'1',
        kbps=>'true',
        fpstype=>'vdr',
        audiotrack=>'all',
        drc=>'2.5',
        aac_bitrate=>'192',
	v=>'vvv',
        });

print Dumper $scan;
