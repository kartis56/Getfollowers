#!/usr/bin/perl


#use warnings ;
#use strict ;
use Data::Dumper;
use DBI;
use DBD::mysql;
use Text::CSV_XS;
use YAML::XS        ;




my $dbh = ConnectToMySql(my $Database);
my $query = "select id FROM user_lookup_ids  ";	
my $sth = $dbh->prepare($query);
#$sth->execute();

print "\n$query\n\n";
#$query = "insert into user_lookup_ids (id) values '999999999999999999'";
#$sth = $dbh->prepare($query);
#$sth->execute();


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;

$year = $year + 1900;
$mon = $mon + 1;

# add a zero if the value is less than 10

if ($sec < 10) { $sec = "0$sec"; }
if ($min < 10) { $min = "0$min"; }
if ($hour < 10) { $hour = "0$hour"; }
if ($mday < 10) { $mday = "0$mday"; }
if ($mon < 10) { $mon = "0$mon"; }
if ($year < 10) { $year = "0$year"; }
if ($wday < 10) { $wday = "0$wday"; }
if ($yday < 10) { $yday = "0$yday"; }
if ($isdst < 10) { $isdst = "0$isdst"; }

my $DateTime = "$year-$mon-$mday $hour:$min:$sec";






# end - while (@data = $sth->fetchrow_array())
#};

exit;

#----------------------------------------------------------------------
sub ConnectToMySql {
#----------------------------------------------------------------------

   my ($db) = @_;

   my $keys = YAML::XS::LoadFile( "./Getfollowers/accessKey")  or die "Can't access login credentials";
#print YAML::XS::Dump($keys);

   my $database = $keys->{db};
   my $host = $keys->{host};
   my $userid = $keys->{userid};
   my $passwd = $keys->{passwd};

   chomp ($database, $host, $userid, $passwd);
   
   my $connectionInfo="dbi:mysql:$db;$host:3306";
   # make connection to database
   my $l_dbh = DBI->connect($connectionInfo,$userid,$passwd, { RaiseError => 1, AutoCommit => 1 });
   return $l_dbh;
=pod
=cut

}

exit;
