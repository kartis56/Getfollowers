#!/usr/bin/perl

# whitelist のユーザの詳細情報を取得し、DBに登録する
#
# Usage:  ./add_whitelist.pl 
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
use Date::Parse;           #str2time
#use DBIx::QueryLog;       #デバッグ時はクエリーログを出す


open IN, '<whitelist.txt' or die "Error : file can't open whitelist.txt\n";

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;

my $debug = 1;  # 0: release,  1:detailed debug,  2:less output debug
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

my @users = ();
while (<IN>) {
    print STDERR $_ ,"\n";
    push @users, $_;
}

if ( $debug == 1 ) {
  print "user Count ",  $#users +1 , "\n" ; 
}
wait_for_rate_limit( 'users_lookup' );
add_white_list(\@users);

close IN;
exit ;


# ====================
sub add_white_list {  # Usage:  get_white_ist( @screen_name) ;
    my $tmp = shift ;  # 

    # ユーザリストに変換
    # 100件ごとに分割して取得
    while ( my @users_100 = splice(@$tmp,0,100) ) {
      if ( $debug == 1 ) { print "Users100  @users_100  --\n" ; }
      my $l_users = join ',', @users_100 ;  # 
      if ( $debug == 1 ) { print "l_users         $l_users  --\n" ; }

      my $user_ref;
        eval{
      $user_ref = $twit->lookup_users( { 'screen_name' => $l_users , 'include_entities' => 'false' } ) ;
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
      foreach my $ref ( @$user_ref ) {             #
        push @bulk , +{
                   'id'              => $ref->{'id'},
                   'screen_name'     => $ref->{'screen_name'},
        };
      }
      if ( $debug == 1 ) {    print Dumper @bulk; }
      $teng->bulk_insert( 'Whitelist' , \@bulk ) ;
    }

    return  ;
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
                 "\n limit is : ", $row->users_lookup_remain ," type is : ", $type ,"\n";
  }


}
