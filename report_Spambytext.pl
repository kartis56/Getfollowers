#!/usr/bin/perl

# R4S.txt����ǂݍ���ŁASpam�񍐂�Blocked��insert����
#     user_ids��find_or_create����
#     spam.txt�֒ǉ�����
#
# Usage:  ./report_Spambytext.pl 
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
#use DBIx::QueryLog;      #�f�o�b�O���̓N�G���[���O���o��

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;
use SQL::Maker::Condition;

my $debug = 1;  # 0: release,  1:detailed debug,  2:less output debug
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);

open OUT2, '>>spamer.txt' ;
open IN, '<R4S.txt' or die "Error : file can't open R4S.txt\n";


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
my @rowall;
my $count = 0;

while (<IN>) {
    $_ =~ s/[\n\r\t]//g ;
    print STDERR $_ ,"\n";

    push @rowall, $_ ;
    $count++;
    if ( ($debug == 1) and ($count == 10) ) { last; }   # debug�� ��10���Ő؂�グ
}
if( $debug == 1) {
  print  Dumper @rowall, "\n";
}

foreach $row ( @rowall ) {
  my $l_name = $row;
  my $tmp = "";
  my $l_id;
  
  print "Found a row: screen_name =   ", $l_name ,  " \n"; 

  wait_for_rate_limit( 'users_r4s' );

  my $err ="";
  my $user_ref;
      eval{
  $user_ref = $twit->report_spam( { 'screen_name' => $l_name  } ) ;
      };
  $err = $@;
  if ( ($err )  and ($err->code == 404) ) {                          # user�Ȃ�
       print  "                                                 No users in Twitter \n";
       $tmp = $teng->update( 'user_ids', { deleted => 1 },  { screen_name => $l_name } );
       if ( $debug == 1) {  print "Update user_ids : $tmp \n"; }
       $tmp = $teng->delete( 'Unknown', { screen_name => $l_name } );
       if ( $debug == 1) {  print "Delete blocked :  $tmp \n"; }
       next; 
  }
  while ( $err  ) { 
       
     if ( $err->code == 403 ){
      print "ERROR                   ". Dumper $err . "\n";
         print "ERROR CODE: $err->code \n"; 
       sleep(901);                                       # �{����50��/h�Ȃ̂ŁA15��/15�� = 60��/h�œ��������Ƃ����403�G���[������  ���̎��͑҂�������
           eval{
       $user_ref = $twit->report_spam( { 'screen_name' => $l_name  } ) ;
           };
       $err = $@;

     } elsif ( $err->code == 404)  {                          # user�Ȃ�
       print  "                                                 No users in Twitter \n";
       $tmp = $teng->update( 'user_ids', { deleted => 1 },  { screen_name => $l_name } );
       if ( $debug == 1) {  print "Update user_ids : $tmp \n"; }
       $tmp = $teng->delete( 'Unknown', { screen_name => $l_name } );
       if ( $debug == 1) {  print "Delete blocked :  $tmp \n"; }
       next; 
     } else { 
          warn "\n when report_spam - HTTP Response Code: ", $err->code, "\n",
               "\n - HTTP Message......: ", $err->message, "\n",
               "\n - Twitter error.....: ", $err->error, "\n";
       die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');   #���warn���Ȃ���warn�����Ɏ���
     }
  }

  $l_id = $user_ref->{'id'};                          # R4S�̌��ʂƂ���id������

=pod    #�����Ȃ�
  my $sql_maker = $teng->sql_builder();        #{ '-or', screen_name => $l_name , 'id' => $l_id }
  my $cond1 = $sql_maker->new_condition();
  my $cond2 = $sql_maker->new_condition();

  $cond1->add( 'screen_name' => $l_name );
  $cond1 |=     $cond2->add( 'id' => $l_id );
  print  Dumper $cond1 ."\n "  ;
  $tmp = $teng->single( 'user_ids', $cond1 );    #  {error}
=cut

  $tmp = $teng->search_named( 'Select * from user_ids where screen_name = :l_name or id = :l_id ;',
                                       +{ 'l_name' => $l_name , 'l_id' => $l_id });             #  name or id ��v�Ȃ�user_ids������
 if ( not defined($tmp) ) {   #user_ids���Ȃ��Ȃ�擾
    my $user_ref;
    wait_for_rate_limit( 'users_lookup' );
        eval{
    $user_ref = $twit->lookup_users( { 'screen_name' => $l_name , 'include_entities' => 'false' } ) ;
        };
    if ( my $err = $@ ) { 
            warn "\n when lookup_ids - HTTP Response Code: ", $err->code, "\n",
                 "\n - HTTP Message......: ", $err->message, "\n",
                 "\n - Twitter error.....: ", $err->error, "\n";
       die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');   #���warn���Ȃ���warn�����Ɏ���
    }
    foreach my $ref ( @$user_ref ) {
      if ( $debug == 1) {  print "user_ids : ", $ref->{'id'},  " \n"; }
      
        $teng->fast_insert( 'user_ids' ,
          +{
                     'id'              => $ref->{'id'},
                     'screen_name'     => $ref->{'screen_name'},
                     'protected'       => $ref->{'protected'},
                     'followers_cnt'   => $ref->{'followers_count'},
                     'friends_cnt'     => $ref->{'friends_count'} 
          }
        );

        $l_id = $ref->{'id'};
    }
  } else {                                 # user_ids ������Ȃ�update����
    my @all = $tmp->all;
    if ( $debug == 1) {  print "user_ids : ". $l_id .  " \n"; }
        $teng->update( 'user_ids' ,
          +{
                     'screen_name'     => $user_ref->{'screen_name'},
                     'protected'       => $user_ref->{'protected'},
                     'followers_cnt'   => $user_ref->{'followers_count'},
                     'friends_cnt'     => $user_ref->{'friends_count'} 
          }, 
          { 'id'              => $l_id, }
        );
 #       print Dumper $teng;
#    if ( $debug == 1) {  print "sql : ". $teng->{'sql'} .  " \n"; }
  }


  my $blocked = $teng->find_or_create( 'Blocked', { id => $l_id, done => 1}, );
  if ($debug == 1) { warn "Blocked :     "  . Dumper   $blocked->get_columns ; }

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