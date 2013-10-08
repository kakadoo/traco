#!/usr/bin/perl -w

use Data::Dumper;
use lib '../lib/';
use Traco::Traco;

my $t = Traco::Traco->new();

#my $b = \$t->message;

my $logger = \&$t->message;


Traco::Traco::message->({msg=>"test test",v=>'vvvvvvv',debug=>'1',});

