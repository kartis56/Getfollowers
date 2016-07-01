#!/usr/bin/perl


#use warnings ;
#use strict ;
use Data::Dumper;
use DBI;
use DBD::mysql;
use Text::CSV_XS;
use YAML::XS        ;




my $dbh = ConnectToMySql(my $Database);
<<<<<<< HEAD
 $dbh->{mysql_use_result} = 1;
=pod
=cut
my $query = "show tables;  ";	
my $sth = $dbh->prepare($query)  or die "prepare Error" , $DBI::errst;
$sth->execute()   or print  "exe Error  $DBI::errst\n";

my $i;
my $names = $sth->{'NAME'};
  my $numFields = $sth->{'NUM_OF_FIELDS'};
  my $keys = $sth->{'mysql_table'};
  
  print "Keys : " , $$keys[0] ,"\n";
  
  for ( $i = 0;  $i < $numFields;  $i++) {
      printf("%s : %s\n", $i+1 , $$names[$i]);
  }
  while (my $ref = $sth->fetchrow_arrayref) {
      $i =0;
      for ( ;  $i < $numFields;  $i++) {
          printf("%d : %s \n", $i+1 , $$ref[$i]);
      }
  }
  
  



 $query = "select * FROM rate_limit;  ";	
 $sth = $dbh->prepare($query)  or die "prepare Error" , $sth->errst . "\n";
$sth->execute()   or print  "exe Error  $DBI::errst\n";
$names = $sth->{'NAME'};  $numFields = $sth->{'NUM_OF_FIELDS'};
  for ( $i = 0;  $i < $numFields;  $i++) {
      printf("%s : %s \n", $i+1 , $$names[$i]);
  }
  while (my $ref = $sth->fetchrow_arrayref) {
  		$i = 0;
  		
      for ($i ;  $i < $numFields;  $i++) {
          printf("%d : %s \n", $i , $$ref[$i]);
      }
      print "\n";
  }

 # Drop table 'foo'. This may fail, if 'foo' doesn't exist
  # Thus we put an eval around it.
  eval { $dbh->do("DROP TABLE foo") };
  print "Dropping foo failed: $@\n" if $@;

  # Create a new table 'foo'. This must not fail, thus we don't
  # catch errors.
  $dbh->do("CREATE TABLE foo (id INTEGER, name VARCHAR(20))");

  # INSERT some data into 'foo'. We are using $dbh->quote() for
  # quoting the name.
  $dbh->do("INSERT INTO foo VALUES (1, " . $dbh->quote("Tim") . ")");

  # same thing, but using placeholders (recommended!)
  $dbh->do("INSERT INTO foo VALUES (?, ?)", undef, 2, "Jochen");

  # now retrieve data from the table.
  my $sth = $dbh->prepare("SELECT * FROM foo");
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref()) {
    print "Found a row: id = $ref->{'id'}, name = $ref->{'name'}\n";
  }

=======
my $query = "select id FROM user_lookup_ids  ";	
my $sth = $dbh->prepare($query);
#$sth->execute();
>>>>>>> effe08bd27e008e951402af1c8ab3d53dcb56a2d

print "\n$query\n\n";
#$query = "insert into user_lookup_ids (id) values '999999999999999999'";
#$sth = $dbh->prepare($query);
#$sth->execute();

<<<<<<< HEAD
 $sth->finish(); 
$dbh->disconnect();
=======
>>>>>>> effe08bd27e008e951402af1c8ab3d53dcb56a2d

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
<<<<<<< HEAD
=======
#----------------------------------------------------------------------
>>>>>>> effe08bd27e008e951402af1c8ab3d53dcb56a2d

   my ($db) = @_;

   my $keys = YAML::XS::LoadFile( "./Getfollowers/accessKey")  or die "Can't access login credentials";
#print YAML::XS::Dump($keys);

   my $database = $keys->{db};
   my $host = $keys->{host};
   my $userid = $keys->{userid};
   my $passwd = $keys->{passwd};

<<<<<<< HEAD

   chomp ($database, $host, $userid, $passwd);
   
   my $connectionInfo="dbi:mysql:$database;$host:3306";
   
   # make connection to database
   my $l_dbh = DBI->connect($connectionInfo,$userid,$passwd, { RaiseError => 1 }) or die "connect Eroor";
=======
   chomp ($database, $host, $userid, $passwd);
   
   my $connectionInfo="dbi:mysql:$db;$host:3306";
   # make connection to database
   my $l_dbh = DBI->connect($connectionInfo,$userid,$passwd, { RaiseError => 1, AutoCommit => 1 });
>>>>>>> effe08bd27e008e951402af1c8ab3d53dcb56a2d
   return $l_dbh;
=pod
=cut

}

<<<<<<< HEAD
=======
exit;
>>>>>>> effe08bd27e008e951402af1c8ab3d53dcb56a2d
