#!/usr/bin/perl

# Unknown のユーザidの件数20件以上を取得し、DB 4R4sに登録する（DBロックがかかり極めて重い）
#     登録後に4R4sを全件取得し、Spam報告しBlockedへinsertする
#     screen_nameが変わっていた場合はuser_idsをupdateする
#     4R4s、Unknownをdeleteする
#
# Usage:  ./report_Spam_byDB.pl 
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
my @sql;
my @itr;
my @ids;
                                                         # あらかじめwhitelist分を削除する

@sql="select id from whitelist ; ";
@itr = $teng->search_by_sql(@sql, undef, 'whitelist' );
foreach $row ( @itr ) {
  push  @ids, $row->id;
}

$teng->delete('4r4s', +{ id => {'IN' => \@ids } } );

#取りたい対象の件数取得
my $limit = "limit 500";                                          # 抽出件数が多すぎる場合は limit 10000 などで指定する
if ( $debug >= 1 ) { $limit = "limit 100" }; 
@sql = q/ select screen_name, id, count from 4R4s order by count DESC / . " $limit" ." ;" ;

my $iter2 = $teng->search_by_sql( @sql ,
                                [], '4R4s' ) 
   or  die "Maybe Allready Getted 4R4s \n" ;
if ( $debug == 1) {   warn Dumper  "sql :  $iter2->{sql} "; }


my $rowall = $iter2->all;

=pod
my $diff = 20;                                      # 4R4s 空の時のcount減衰値
if ( $debug == 1) {   print "count row : ",  scalar(@$rowall) ,"\n"; }

my $count = 400;
while ( scalar (@$rowall) == 0 ) {              # 4R4sが空なら、何件かできるまで作成する
  $count -= $diff;
  if ( $count <= 20 ) { print "Too less counter $count  "; die;  }
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
=cut                                                    # 4r4s作成を Unknownのトリガーにしたので不要


foreach $row ( @$rowall ) {
  my $l_id = $row->id;
  my $l_name = $row->screen_name;
  my $tmp;
  
  print "Found a row: screen_name =   ", $l_name , "       id =       ", $l_id , " \n"; 

  wait_for_rate_limit( 'users_r4s' );

  my $err ="";
  my $user_ref;
  my $cnt = $row->count;
  
  do { 
      eval{
    $user_ref = $twit->report_spam( { 'user_id' => $l_id  } ) ;
      };
    $err = $@;
       
    if ($err ) {
     if ( $err =~ /403/ ){
       print "ERROR CODE: $err \n"; 
       sleep(901);                                       # 本当は50件/hなので、15件/15分 = 60件/hで動かそうとすると403エラーが来る  この時は待つしか無い
     } elsif  ($err =~ /404/)  {                          # userなし ループ内周回時チェック
       if ( $debug == 1) {  print "ERROR CODE: $err \n"; }
          print  "                                                 No users in Twitter \n";
       $row->delete();
       $tmp = $teng->delete( 'Blocked', { id => $l_id } );
       if ( $debug == 1) {  print "Delete blocked : $tmp \n"; }
       $tmp = $teng->update( 'user_ids', { deleted => 1 },  { id => $l_id } );
       if ( $debug == 1) {  print "Update user_ids : $tmp \n"; }
       $tmp = $teng->delete( 'Unknown', { id => $l_id } );
       if ( $debug == 1) {  print "Delete Unknown : $tmp \n"; }
       next; 
      } elsif ( $err->code =~ /500|50[2-4]/ ) {                          # can't connect
        if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
           print STDERR "                                          cant connect Twitter $l_id : $err \n";
        sleep(10); 
     } else { 
          warn "\n when report_spam - HTTP Response Code: ", $err->code, "\n",
               "\n - HTTP Message......: ", $err->message, "\n",
               "\n - Twitter error.....: ", $err->error, "\n";
       die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');   #先にwarnしないとwarnせずに死ぬ
     }
    }
  }while ( $err );

  my $blocked = $teng->find_or_create( 'Blocked', { id => $l_id, done => 1}, );
  if ($debug == 1) { warn Dumper   $row->get_columns ; }

  $tmp = $teng->delete( 'Unknown', { id => $l_id } );
  if ( $debug == 1) {  print "Delete Unknown : $tmp \n"; }

  if ( $cnt == $tmp) {
    $tmp = $teng->delete( '4R4s', { id => $l_id } );
  } else {                                                #  処理中にUnknownが追加されているなら
    $cnt = $tmp - $cnt;
    $tmp = $teng->update( '4R4s', { count =>  $cnt }, { id => $l_id }  );
  }
  open OUT2, '>>spamer.txt' ;
  OUT2->autoflush(1);
  print OUT2 $l_name ,"\r\n";
  close OUT2;
}

exit ;





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
  
  print "\$wait_remain  : $wait_remain      Type:  $type\n";
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
