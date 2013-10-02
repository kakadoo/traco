use lib 'lib/';
use Traco::Config;
use Data::Dumper;

my $c=Traco::Config->new();

print Dumper $c;

print $c->{'vdr_user'} . "\n";






