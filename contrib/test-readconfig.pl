use Traco::Traco;
use Data::Dumper;
my $t=Traco::Traco->new();

my $rc = $t->parseconfig({config=>'./traco.conf',debug=>'1',});

print Dumper $rc;


