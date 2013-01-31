#!/usr/bin/perl -w
use Traco::Traco ;
use Data::Dumper ;

#my $file = '/opt/video.00/Manhattan_Love_Story/2011-03-05.15.25.6-0.rec/00001.ts';
my $file = '/opt/video.00/Underworld/2011-04-24.22.07.7-0.rec/vdrtranscode.ts';

#my $file = '/mnt/video.00/Backdraft_-_Männer,_die_durchs_Feuer_geh/2011-03-26.23.30.2-0.rec/00001.ts';
#my  $file= '/opt/video.00/Das_Leben_des_Brian/2011-05-05.20.14.23-0.rec/00001.ts';
#my $file = '/opt/video.00/Das_Leben_des_Brian/2011-05-05.20.14.23-0.rec/00001.ts';




my $vdrtranscode = Traco::Traco->new();
my $config = \$vdrtranscode->_parseconfig({config=>'/etc/vdr/vdrtranscode.conf',debug=>'1',});



my $handbrake = \$vdrtranscode->_handbrakeanalyse({file=>$file,nice=>'20',handbrake=>'/usr/bin/HandBrakeCLI',debug=>'1',kbps=>'true'});
#print Dumper $handbrake;

my $hbopts = \$vdrtranscode->prepare_audio_tracks({audiotrack=>'all',hbanalyse=>${$handbrake},config=>${$config},debug=>'1',});

print Dumper $hbopts;

