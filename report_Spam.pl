#!/usr/bin/perl

# Unknown �̃��[�Uid�̌���20���ȏ���擾���ADB 4R4s�ɓo�^����iDB���b�N��������ɂ߂ďd���j
#     �o�^���4R4s��S���擾���ASpam�񍐂�Blocked��insert����
#     screen_name���ς���Ă����ꍇ��user_ids��update����
#     4R4s�AUnknown��delete����
#
# Usage:  ./report_Spam_byDB.pl 
#
#// cygwin�@��perl -MCPAN -e shell
# cpan install Encode Net::Twitter::Lite YAML::XS Scalar::Util Data::Dumper DBI DBD::mysql Teng lib
#
#
# ���炩���� https://dev.twitter.com/apps ���o�^���āAOAuth�F�؂ɕK�v��
# consumer_key, consumer_secret, access_token, access_token_secret ���擾���A
# ../keys.txt�ɋL�ڂ��邱��
# ../accessKey ��DB�Ahost,user,passwd���L�ڂ��邱��
#

use warnings ;
use strict ;
use Data::Dumper;
use Net::Twitter::Lite::WithAPIv1_1;
use YAML::XS        'LoadFile';
use Scalar::Util 'blessed';
use IO::Handle;            #�I�[�g�t���b�V��
use POSIX;
use Date::Parse;           #str2time
#if ($debug >= 1) {  use DBIx::QueryLog;   }    #�f�o�b�O���̓N�G���[���O���o��

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;

my $debug = 1;  # 0: release,  1:detailed debug,  2:less output debug
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);

open OUT2, '>>spamer.txt' ;
#open IN, '<R4S.txt' or die "Error : file can't open R4S.txt\n";


STDOUT->autoflush(1);
STDERR->autoflush(1);
OUT2->autoflush(1);

   my $keys = YAML::XS::LoadFile( "../accessKey")  or die "Can't access login credentials";

   my $database = $keys->{db};
   my $host = $keys->{host};
   my $userid = $keys->{userid};
   my $passwd = $keys->{passwd};


   chomp ($database, $host, $userid, $passwd);
   
   my $connectionInfo="dbi:mysql:$database;$host:3306";
   
   # make connection to database
   my $teng = MyApp::DB->new(
     connect_info => [$connectionInfo, $userid, $passwd, +{ RaiseError => 1, mysql_use_result => 1 }, ],
     schema_class => 'MyApp::DB::Schema', ) or die "connect Error";
     

my $row;




#��肽���Ώۂ̌����擾
my $limit = "";                                          # ���o��������������ꍇ�� limit 10000 �ȂǂŎw�肷��
if ( $debug >= 1 ) { $limit = "limit 100" }; 
my @sql = q/ select screen_name, id from 4R4s order by count DESC / . " $limit" ." ;" ;

my $iter2 = $teng->search_by_sql( @sql ,
                                [], '4R4s' ) 
   or  die "Maybe Allready Getted 4R4s \n" ;
if ( $debug == 1) {   warn Dumper  "sql :  $iter2->{sql} "; }

#my $count = 0;
#my @users = ();

my $rowall = $iter2->all;

my $diff = 2;
if ( $debug == 1) {   print "count row : ",  scalar(@$rowall) ,"\n"; }

my $count = 17;
while ( scalar (@$rowall) == 0 ) {              # 4R4s����Ȃ�A�������ł���܂ō쐬����
  $count -= $diff;
  if ( $count <= 8 ) { print "Too less counter $count  "; die;  }
  my @sql2 = "insert 4R4s(screen_name,id,count) select screen_name,id,count(id) as cnt from Unknown  group by id having cnt >= $count order by screen_name  ;" ;
                                                                          # " . $limit ." having cnt   # having cnt >= $count ;", )  order by cnt DESC
  $teng->do( @sql2, ) 
         or die  "insert error to 4R4s  \n\n\n\n";

  $iter2 = $teng->search_by_sql( @sql ,
                                  [], '4R4s' ) 
         or  die "Maybe search error 4R4s \n" ;
  if ( $debug == 1) {   warn Dumper  "sql :  $iter2->{sql} \n"; }
  $rowall = $iter2->all;
  if ( $debug == 1) {   print "count row : ",  scalar(@$rowall) ,"\n"; }
}

foreach $row ( @$rowall ) {
  my $l_id = $row->id;
  my $l_name = $row->screen_name;
  my $tmp;
  
  if ( $debug >= 1) {
    print "Found a row: screen_name =   ", $l_name , "       id =       ", $l_id , " \n"; 
  }

  wait_for_rate_limit( 'users_r4s' );

  my $err ="";
  my $user_ref;
      eval{
  $user_ref = $twit->report_spam( { 'user_id' => $l_id  } ) ;
      };
  $err = $@;
  print "TMPERROR    "   . Dumper $err;
  
  if ( ($err )  and ($err->code == 404) ) {                          # user�Ȃ�
    if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
       print  "                                                 No users in Twitter \n";
    $row->delete();
    $tmp = $teng->delete( 'Blocked', { id => $l_id } );
    if ( $debug == 1) {  print "Delete blocked : $tmp \n"; }
    $tmp = $teng->update( 'user_ids', { deleted => 1 },  { id => $l_id } );
    if ( $debug == 1) {  print "Update user_ids : $tmp \n"; }
    $tmp = $teng->delete( 'Unknown', { id => $l_id } );
    if ( $debug == 1) {  print "Delete blocked : $tmp \n"; }
    next; 
  }
  while ( $err  ) { 
       
     if ( $err->code == 403 ){
       if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
       sleep(901);                                       # �{����50��/h�Ȃ̂ŁA15��/15�� = 60��/h�œ��������Ƃ����403�G���[������  ���̎��͑҂�������
           eval{
       $user_ref = $twit->report_spam( { 'user_id' => $l_id  } ) ;
           };
       $err = $@;

     } elsif  ($err->code == 404)  {                          # user�Ȃ� ���[�v�����񎞃`�F�b�N
       if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
          print  "                                                 No users in Twitter \n";
       $row->delete();
       $tmp = $teng->delete( 'Blocked', { id => $l_id } );
       if ( $debug == 1) {  print "Delete blocked : $tmp \n"; }
       $tmp = $teng->update( 'user_ids', { deleted => 1 },  { id => $l_id } );
       if ( $debug == 1) {  print "Update user_ids : $tmp \n"; }
       $tmp = $teng->delete( 'Unknown', { id => $l_id } );
       if ( $debug == 1) {  print "Delete blocked : $tmp \n"; }
       next; 
     } else { 
          warn "\n when report_spam - HTTP Response Code: ", $err->code, "\n",
               "\n - HTTP Message......: ", $err->message, "\n",
               "\n - Twitter error.....: ", $err->error, "\n";
       die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');   #���warn���Ȃ���warn�����Ɏ���
     }
  }

  my $blocked = $teng->find_or_create( 'Blocked', { id => $l_id, done => 1}, );
  if ($debug == 1) { warn Dumper   $row->get_columns ; }

  $tmp = $teng->delete( 'Unknown', { id => $l_id } );
  if ( $debug == 1) {  print "Delete blocked : $tmp \n"; }

  $tmp = $teng->delete( '4r4s', { id => $l_id } );
  print OUT2 $l_name ,"\r\n";
  
}

exit ;





############################## ver 2016/08/15 use $l_limit = $type , "_limit"  and  print lastupdt
############################ APP�s���ɑΉ��ς�
sub wait_for_rate_limit {        #  wait_for_rate_limit( $type ) 
  my $type = shift;
  my $row = $teng->single( 'rate_limit', {id => 1} );

  my $l_limit = "$type" . "_limit";
  my $l_remain = "$type" . "_remain";
  my $l_reset = "$type" . "_reset";
  my $wait_remain = $row->$l_remain;
  my $app_remain = $row->app_limit_remain;
  my $time = $row->$l_reset || 0;

  my $old = str2time($row->lastupdt,'JST');
  print "rate_limit foward update time:  " . $row->lastupdt ."\n";
  
  if (( ($old +900) <= time ) or ( $time <= time ) ) {        # �O��擾��������15���o���Ă��� �܂��̓��Z�b�g���Ԃ������O�Ȃ�rate_limit���Ď擾����
      do `./get_rate_limit.pl`;                    #�o�b�N�_�b�V�� (Shift+@)
      $row = $teng->single( 'rate_limit', {id => 1} );
  }
  
  $wait_remain = $row->$l_remain;
  $app_remain = $row->app_limit_remain;
  $time = $row->$l_reset || 0;
  
  print "\$wait_remain  : $wait_remain \n";
  print "   \$app_remain  : $app_remain \n";

  while ( $app_remain <= 2 or $wait_remain <= 2 ) {   #app_remain �� type��remain ���c�菭�Ȃ��Ȃ�ҋ@
    my $sleep_time = $time - time;
      if ($debug ==1) {
          print STDERR " -- API limit reached in wait_for_limit, waiting for $sleep_time seconds -- type is : $type \n" ; 
          print "----------------------- At until Loop\n";
      }
    print "wait rate_limit until -------" , POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time )) , "\n";
      sleep ( $sleep_time + 1 );
    do `./get_rate_limit.pl`;                    #�o�b�N�_�b�V�� (Shift+@)
    $row = $teng->single( 'rate_limit',{id => 1} );
    $wait_remain = $row->$l_remain;
    $app_remain = $row->app_limit_remain;
    $time = $row->$l_reset;
    $sleep_time = $time - time;
    
    if ( $sleep_time <= 0 ){        # reset���ߋ��̂��Ƃ�����
       $time = time + 60;
    }
    if ( $debug == 1) {
      print STDERR "wait_for_rate_limit next Loop: ". POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time ))
                  ."\n limit is : ". $wait_remain ." type is : ". $type . "\n"; 
    }
  }
  $wait_remain--;   # �g���O�Ɍ��炵�Ă���
  $app_remain--;
  $teng->update( 'rate_limit', {$l_remain => $wait_remain , app_limit_remain  => $app_remain}, +{id => 1} );  #�Ăяo���x��DB��������炷
  if ( $debug == 1 ) {
    print STDERR "wait_for_rate_limit after Loop: ",  POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time ) ) ,
                 "\n limit is : ", $row->users_lookup_remain ," type is : ", $type ,"\n";
  }


}
