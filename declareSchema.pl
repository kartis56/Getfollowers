#! perl
use strict;
use warnings;
use DBI;
use Teng::Schema::Dumper;
use YAML::XS      ;

   my $keys = YAML::XS::LoadFile( "../accessKey")  or die "Can't access login credentials";

   my $database = $keys->{db};
   my $host = $keys->{host};
   my $userid = $keys->{userid};
   my $passwd = $keys->{passwd};


   chomp ($database, $host, $userid, $passwd);
   
   my $connectionInfo="dbi:mysql:$database;$host:3306";

   my $dbh = DBI->connect($connectionInfo,$userid,$passwd, { RaiseError => 1 }) or die "connect Eroor";
print Teng::Schema::Dumper->dump(
    dbh       => $dbh,
    namespace => 'MyApp::DB',
), "\n";
