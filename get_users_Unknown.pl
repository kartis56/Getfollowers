#!/usr/bin/perl

# Unknown �̂���(���[�U�擾�ς݂łȂ���id���X�V�ł��Ȃ�����)���[�U�̏ڍ׏����擾���ADB�ɓo�^����
#
# Usage:  ./get_users_Unknown.pl 
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
#use DBIx::QueryLog;       #�f�o�b�O���̓N�G���[���O���o��

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;

open TMP, '>>del_Unk.txt' ;


my $debug = 0;  # 0: release,  1:detailed debug,  2:less output debug
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);

STDOUT->autoflush(1);
STDERR->autoflush(1);
TMP->autoflush(1);

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
my $limit = "limit 720000";                                          # ���o��������������ꍇ�� limit 10000 �ȂǂŎw�肷��
if ( $debug >= 1 ) { $limit = "limit 10" }; 
my @sql = q/ select screen_name from Unknown where id ='0' group by screen_name / . " $limit" ." ;" ;

my $iter = $teng->search_by_sql( @sql ,
                                [], 'Unknown' ) 
   or  die "Maybe Allready Getted Blocked user \n" ;
if ( $debug == 1) {   warn Dumper  "sql :  $iter->{sql} "; }

my $count = 0;
my @users = ();
my @allrows = $iter->all;
foreach $row ( @allrows ) {
  if ( $debug >= 1) {
   print "Found a row: screen_name = ", $row->screen_name ," \n"; 
  }
  push @users , $row->screen_name;
  $count++;
  if ( $count == 100) {
    # 100�����ƂɎ擾
    wait_for_rate_limit( 'users_lookup' );
    get_users( \@users );
    $count =0 ;
    @users = ();
    print TMP "End get users    -------------------------------------------------------------------------------------\n";
    print "End get users    -------------------------------------------------------------------------------------\n";
  }
    
  
}

if ( $count >= 1 )  {     # 100�������̕��������
  wait_for_rate_limit( 'users_lookup' );
    print TMP "Last get users    -------------------------------------------------------------------------------------\n";
    print "Last get users    -------------------------------------------------------------------------------------\n";

  get_users( \@users );
}

exit ;




sub get_users {   #### lookup_user�̐����ɂ��100���܂�
    @_ or die "ERROR: get_users() : user_id_list is empty\n" ;
    scalar (@_) <= 100 or die "ERROR: get_users() : user_id_list > 100\n" ;
    my $tmp = shift;
    my $l_users = join ',', @$tmp ;  # 
    if ( $debug == 1 ) { print TMP "         userslist    \n   $l_users  --\n" ; }
    my $l_users_cnt = scalar(@$tmp) ; 
     if ( $debug == 1 ) { print TMP "        userc_count   \n  $l_users_cnt  --\n" ; }
   
    my $user_ref = undef;
        eval{
    $user_ref = $twit->lookup_users( { 'screen_name' => $l_users , 'include_entities' => 'false' } ) ;
        };
    if ( my $err = $@ ) { 
            warn "\n when lookup_ids - HTTP Response Code: ", $err->code, "\n",
                 "\n - HTTP Message......: ", $err->message, "\n",
                 "\n - Twitter error.....: ", $err->error, "\n";
       die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');   #���warn���Ȃ���warn�����Ɏ���
    }
    my $user_cnt = scalar(@$user_ref); 
    print TMP "user_ref Count ",  $user_cnt, "\n" ; 

    my @bulk = ();
    my @upd_users = ();
#    my @del_users = ();
    my %diff_cnt =(); 
    foreach my $ref ( @$user_ref ) {             # ���łɍ폜����Ă�A�J�E���g�� lookup_users���Ă�return����Ȃ��̂ŗv���������ԋp����
      push @bulk , +{
                 'id'              => $ref->{'id'},
                 'screen_name'     => $ref->{'screen_name'},
                 'protected'       => $ref->{'protected'},
                 'followers_cnt'   => $ref->{'followers_count'},
                 'friends_cnt'     => $ref->{'friends_count'} 
      };
      push @upd_users, +{
                        'id'          =>$ref->{'id'},
                        'screen_name' =>$ref->{'screen_name'}
      };
      $diff_cnt{ $ref->{'screen_name'} }--;
    }
    if ( $debug >= 1 ) {    print Dumper @bulk; }
    
    
    my $upd_cnt = 0;
    if ( scalar( @bulk ) > 0 ) {                   # ���Ȃ��Ƃ�1����user���������ꍇ��insert
      $teng->bulk_insert( 'user_ids' , \@bulk ) ;
    
      foreach my $ref ( @upd_users ) {                      # �擾�ł������ŃA�b�v�f�[�g����
        $upd_cnt += $teng->update('Unknown', + {id => $ref->{'id'} , screen_name => $ref->{'screen_name'}} , +{ 'screen_name' => $ref->{'screen_name'} });
  #      if ( $debug >= 1 ) {
            print TMP "update id: $ref->{'id'}       screen_name:   $ref->{'screen_name'}    Count: $upd_cnt \n";
  #      }
      }
  #my $guard = DBIx::QueryLog->guard();
      print TMP "Update Unknown : $upd_cnt \n";
    }
    
    ######         lookup_users �͑啶����������������screen_name ��v�������̂����̂Ŕz�񍷕��ŏ��O�ł��Ȃ�
    # lookup_users �Ŏ擾�ł��Ȃ����������폜����
    if ( scalar( @bulk ) < 100 ) {
      my @del_users = grep { ++$diff_cnt{$_} == 1 } @$tmp;  
      print  TMP Dumper @del_users  ; 
      my $del_cnt = $teng->delete('Unknown', +{  screen_name => {'IN' => \@del_users }, id => undef } );
      print TMP "Delete Unknown : $del_cnt \n";
    }
    
}



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
  
  print "\$wait_remain  : $wait_remain      Type:  $type\n";
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
                 "\n limit is : ", $wait_remain ," type is : ", $type ,"\n";
  }


}
