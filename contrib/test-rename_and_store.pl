use Traco::Traco;
use Data::Dumper;
my $t=Traco::Traco->new();
my $dir='/opt/video.00/Total_Recall_-_Die_totale_Erinnerung/2011-08-06.22.34.22-0.rec';

my $rc = $t->rename_and_store({dir=>$dir,filenameformat=>'%t-(%vxx%vy,%fps,%d.%m.%y).%c',debug=>'1',destination=>'/opt/video.00/film',});

print Dumper $rc;


