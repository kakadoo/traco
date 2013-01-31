#!/usr/bin/perl -w
use Traco::Traco ;
use Data::Dumper ;

my $file = '/opt/video.00';
my $vdrtranscode = Traco::Traco->new();



my $test = $vdrtranscode->recalculate_video_bitrate({frames=>'172816',fps=>'25',wish_bitrate=>'1200',aac_nr=>'1',ac3_nr=>'1',aac_bitrate=>'128',ac3_bitrate=>'375',});

print Dumper $test;



