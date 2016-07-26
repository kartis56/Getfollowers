#! perl
# Dumper of ./lib/MyApp/DB/Schema.pm 

use strict;
use warnings;
use DBI;
use Teng::Schema::Dumper;
use YAML::XS      ;
open OUT, '>./lib/MyApp/DB/Schema.pm' ;

   my $keys = YAML::XS::LoadFile( "../accessKey")  or die "Can't access login credentials";

   my $database = $keys->{db};
   my $host = $keys->{host};
   my $userid = $keys->{userid};
   my $passwd = $keys->{passwd};


   chomp ($database, $host, $userid, $passwd);
   my $connectionInfo="dbi:mysql:$database;$host:3306";

   my $dbh = DBI->connect($connectionInfo,$userid,$passwd, { RaiseError => 1 }) or die "connect Error";

print OUT Teng::Schema::Dumper->dump(
    dbh       => $dbh,
    namespace => 'MyApp::DB',

    inflate   => +{ rate_limit => q|
            use Date::Parse;
            use DateTime;
        inflate qr/.+_reset/ => sub {
            my ($col_value) = @_;
            return str2time($col_value,'JST');
        };
        deflate qr/.+_reset/ => sub {
            my ($col_value) = @_;
            return  DateTime->from_epoch(epoch => $col_value, time_zone => 'Asia/Tokyo');
        };
    |,},
), "\n";


close OUT;
exit ;
