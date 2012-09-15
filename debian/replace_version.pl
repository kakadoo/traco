#!/usr/bin/perl -w
use strict;
use warnings;

if ( not ( defined $ARGV[0] ) ) { exit 1; }
my $newverline = $ARGV[0] ;

#my $newverline = 'Version: 201112091408' ;
print "got $newverline\n";

my @control;
my @newcontrol;

open my $RO , '<' , 'traco/DEBIAN/control' or die $!;
while (<$RO>) {
chomp ;
push @control ,$_;
}
close $RO or die $!;

for my $l (@control) {
        if ( $l !~ /^Version[:]\s\d+$/smx ) {
                push @newcontrol, $l;
        } else {
                push @newcontrol, $newverline ;
        }
}

open my $WR , '>' , 'traco/DEBIAN/control' or die $!;
for my $l (@newcontrol) {
        if ( $l ) {
        print {$WR} "$l\n";
        }
}
close $WR or die $!;
        
1;

