#!/usr/bin/perl

# Blocked のユーザの詳細情報を取得し、DBに登録する
#
# Usage:  ./get_users.pl 
#
#// cygwin　でperl -MCPAN -e shell
# cpan install Encode Net::Twitter::Lite YAML::XS Scalar::Util Data::Dumper DBI DBD::mysql Teng lib
#
#
# あらかじめ https://dev.twitter.com/apps より登録して、OAuth認証に必要な
# consumer_key, consumer_secret, access_token, access_token_secret を取得し、
# ../keys.txtに記載すること
# ../accessKey にDB、host,user,passwdを記載すること
#

use warnings ;
use strict ;
use Data::Dumper;
use Net::Twitter::Lite::WithAPIv1_1;
use YAML::XS        'LoadFile';
use Scalar::Util 'blessed';
use IO::Handle;            #オートフラッシュ
use POSIX;
#if ($debug >= 1) {  use DBIx::QueryLog;   }    #デバッグ時はクエリーログを出す

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;

my $debug = 0;  # 0: release,  1:detailed debug,  2:less output debug
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);

STDOUT->autoflush(1);
STDERR->autoflush(1);

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

        eval{
    do `./get_rate_limit.pl`;    # 初回 rate_limit取得
        };
    if ( my $err = $@ ) { 
       warn "Maybe too much call TwitterAPI \n";
       die $@ unless blessed $err ;
    }



#取りたい対象の件数取得
my $count = $teng->count( 'Blocked', 'id', +{ done => '0' } ) or  die "Maybe Allready Getted Blocked user \n" ;
if( $debug >= 1 ) { $count = 200; }     #デバッグ時はループ二回で終わらせといてやらあ
$count = POSIX::ceil( $count /100 );
print "Blocked Loop Counter $count \n";
while ( $count > 0 ) {
  my $iter = $teng->search( 'Blocked', +{ done => '0' } ,+{ order_by => 'id ASC', limit => 100} );
  if ( $debug == 1) {   warn Dumper  "sql :  $iter->{sql} "; }

  my @ids = ();

  while ( $row = $iter->next) {
    if ( $debug == 1) {
     print "Found a row: id = ", $row->id ," done = ", $row->done ," \n"; 
    }
    push @ids , $row->id;
    
  }
  if ( $debug >=2 ) {
    print "user Count ",  $#ids +1 , "\n" ; 
  }
  # 100件ごとに取得
  wait_for_rate_limit( 'users' );
  get_users( \@ids );
  print "loop-- $count \n";
  $count--;
  
}

exit ;




sub get_users {   #### lookup_userの制限により100件まで
    @_ or die "ERROR: get_users() : user_id_list is empty\n" ;
    scalar (@_) <= 100 or die "ERROR: get_users() : user_id_list > 100\n" ;
    my $tmp = shift;
    my $l_ids = join ',', @$tmp ;  # 
    if ( $debug == 1 ) { print "$l_ids  --\n" ; }
    my $l_ids_cnt = scalar(@$tmp) ; 
     if ( $debug == 1 ) { print "$l_ids_cnt  --\n" ; }
   
    my $user_ref;
        eval{
    $user_ref = $twit->lookup_users( { 'user_id' => $l_ids , 'include_entities' => 'false' } ) ;
        };
    if ( my $err = $@ ) { 
            warn "\n when lookup_ids - HTTP Response Code: ", $err->code, "\n",
                 "\n - HTTP Message......: ", $err->message, "\n",
                 "\n - Twitter error.....: ", $err->error, "\n";
       die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');   #先にwarnしないとwarnせずに死ぬ
    }
    my $user_cnt = scalar(@$user_ref); 
    print "user_ref Count ",  $user_cnt, "\n" ; 

    my @bulk;
    my @upd_ids;
    my @del_ids;
    foreach my $ref ( @$user_ref ) {             # すでに削除されてるアカウントは lookup_usersしてもreturnされないので要求件数＞返却件数
      push @bulk , +{
                 'id'              => $ref->{'id'},
                 'screen_name'     => $ref->{'screen_name'},
                 'protected'       => $ref->{'protected'},
                 'followers_cnt'   => $ref->{'followers_count'},
                 'friends_cnt'     => $ref->{'friends_count'} 
      };
      push @upd_ids, $ref->{'id'};               # 取得できた分でアップデートする
    }
    if ( $debug == 1 ) {    print Dumper @bulk; }
    $teng->bulk_insert( 'user_ids' , \@bulk ) ;

    foreach my $ref ( @$tmp ) {                 # user取得できなかった分を削除する
      push @del_ids , $ref ;
    }
    if ( $debug >= 1 ) {
        print Dumper "update id: @upd_ids \n";
    }
#my $guard = DBIx::QueryLog->guard();
    $tmp = $teng->update('Blocked', +{ done => '1' }, + {id => {'IN' => \@upd_ids }} );
    print "Update blocked : $tmp \n";
    
    # updateした件数が100未満なら、userを取得できなかったidを削除する
    if ( $tmp < 100 ) {
      $tmp = $teng->delete('Blocked', +{ done => '0', id => {'IN' => \@del_ids }} );
      print "Delete blocked : $tmp \n";
    }
    
}



############################## ver 2016/08/15 use $l_limit = $type , "_limit"  and  print lastupdt
############################ APP不足に対応済み
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
  
  if (( ($old +900) <= time ) or ( $time <= time ) ) {        # 前回取得日時から15分経っている またはリセット時間が今より前ならrate_limitを再取得する
      do `./get_rate_limit.pl`;                    #バックダッシュ (Shift+@)
      $row = $teng->single( 'rate_limit', {id => 1} );
  }
  
  $wait_remain = $row->$l_remain;
  $app_remain = $row->app_limit_remain;
  $time = $row->$l_reset || 0;
  
  print "\$wait_remain  : $wait_remain \n";
  print "   \$app_remain  : $app_remain \n";

  while ( $app_remain <= 2 or $wait_remain <= 2 ) {   #app_remain か typeのremain が残り少ないなら待機
    my $sleep_time = $time - time;
      if ($debug ==1) {
          print STDERR " -- API limit reached in wait_for_limit, waiting for $sleep_time seconds -- type is : $type \n" ; 
          print "----------------------- At until Loop\n";
      }
    print "wait rate_limit until -------" , POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time )) , "\n";
      sleep ( $sleep_time + 1 );
    do `./get_rate_limit.pl`;                    #バックダッシュ (Shift+@)
    $row = $teng->single( 'rate_limit',{id => 1} );
    $wait_remain = $row->$l_remain;
    $app_remain = $row->app_limit_remain;
    $time = $row->$l_reset;
    $sleep_time = $time - time;
    
    if ( $sleep_time <= 0 ){        # resetが過去のことがある
       $time = time + 60;
    }
    if ( $debug == 1) {
      print STDERR "wait_for_rate_limit next Loop: ". POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time ))
                  ."\n limit is : ". $wait_remain ." type is : ". $type . "\n"; 
    }
  }
  $wait_remain--;   # 使う前に減らしておく
  $app_remain--;
  $teng->update( 'rate_limit', {$l_remain => $wait_remain , app_limit_remain  => $app_remain}, +{id => 1} );  #呼び出す度にDBからも減らす
  if ( $debug == 1 ) {
    print STDERR "wait_for_rate_limit after Loop: ",  POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time ) ) ,
                 "\n limit is : ", $wait_remain ," type is : ", $type ,"\n";
  }


}
