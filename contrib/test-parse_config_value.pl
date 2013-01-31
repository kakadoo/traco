use Traco::Traco;
use Data::Dumper;
my $t=Traco::Traco->new();

my $rc = $t->_parse_config_value({value=>'no',debug=>'1',});

print Dumper $rc;

if ($rc) {
print "$rc match\n";
}
