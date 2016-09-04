#!/usr/bin/perl

# Twitterで特定ユーザのフォロワー一覧を取得し、テキスト形式で出力する
#
# Usage:  ./get_followers_list.pl 
#
# spamer.txtで指定したユーザ(screen_name)一覧の、自分がブロック中以外のフォロワー一覧を取得する
# 出力結果は Unknown(DB)
# 
#// cygwin　でperl -MCPAN -e shell
# cpan install Encode  Net::Twitter::Lite YAML::XS Scalar::Util IO::Handle Data::Dumper
#
#
# あらかじめ https://dev.twitter.com/apps より登録して、OAuth認証に必要な
# consumer_key, consumer_secret, access_token, access_token_secret を取得し、
# keys.txtに記載すること
#

use warnings ;
use strict ;
use Data::Dumper;
use Net::Twitter::Lite::WithAPIv1_1;

eval 'use Encode ; 1' or              # 文字コード変換、ない場合はエラー表示
    die "ERROR : cannot load Encode\n" ;
use YAML::XS        'LoadFile';
use Scalar::Util 'blessed';
use IO::Handle;            #オートフラッシュ
use POSIX;
#use DBIx::QueryLog;
use Date::Parse;           #str2time

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;
#use Teng::Plugin::InsertOrUpdate;

#open TMP, '>>work.txt' ;

open IN, '<spamer.txt' or die "Error : file can't open spamer.txt\n";



my $check_block = 0;                              #ブロック済みは処理しないなら 1 ブロック済みかどうか関係なく取得するなら 0

my $debug = 0;
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);

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

#$teng->sql_builder->load_plugin('InsertOnDuplicate');
my $wait_remain = 1;

STDERR->autoflush(1);
STDOUT->autoflush(1);
while (<IN>) {
    print STDERR $_ ,"\n";
    get_followers_list($_);
}

exit ;


# ====================
sub get_followers_list {  # Usage:  get_followers_list($screen_name) ;
    my %arg ;
    $arg{'screen_name'} = $_[0] ;  # API仕様として空白の場合は自分のフォロワー取得になるので注意
    if ($debug == 1) { print " arg ".  $arg{'screen_name'} .' $_0 '. $_[0] ." --\n" ; }
    
    if ( $arg{'screen_name'} == "\r\n" ) { exit; }   #空なら終了
    
    $arg{'cursor'} = -1 ;  # 1ページ目は -1 を指定
    my @l_ids ;
    my $ids_ref;
    my $followers_ref;
    my $err = "";
    my @ins_users = ();
    my @ins_unk = ();


    while ($arg{'cursor'}){ # 一度に5000までしか取得できないのでcursorを書き換えながら取得を繰り返す

        if ($debug == 1) { print " -- getfollowers call  --\n" ; }
        do { 
            wait_for_rate_limit('followers_ids');
          eval{
            $followers_ref = $twit->followers_ids({%arg});
          };
            $err = $@;
            if ($err ) {
              if ($err =~ /404/) {                          # userなし
                if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
                   print  "                                        No users in Twitter $arg{'screen_name'} : $err  \n";
                last; 
              } elsif ( $err =~ /401/) {                          # protected or baned
                if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
                   print  "                                        Protected or BANed users in Twitter $arg{'screen_name'} :   $err   \n";
                return; 
              } elsif ( $err =~ /429|420/ ) {                          # Too Many Req
                if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
                   print  "                                          TooMany Request $arg{'screen_name'} : $err \n";
                sleep(60); 
              } elsif { $err->code =~ /500/) {                          # can't connect
                if ( $debug == 1) {  print "ERROR CODE: $err->code \n"; }
                   print  "                                          cant connect Twitter $arg{'screen_name'} : $err \n";
                sleep(10); 
              } else {
                        warn "\n when followers_ids - HTTP Response Code: ", $err->code, "\n",
                        "\n - HTTP Message......: ", $err->message, "\n",
                        "\n - Twitter error.....: ", $err->error, "\n";
                        die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
              }
            }
        } while ( $err  ) ;
            
        @l_ids = @{ $followers_ref->{'ids'} };
        $arg{'cursor'} = $followers_ref->{'next_cursor'} ;
        print STDERR "Fetched: ids=", scalar @l_ids, ",next_cursor=$arg{'cursor'}\n" ;

        # ユーザリストに変換
        # 100件ごとに分割して取得
        #TMP->autoflush(1);
        while (my @ids_100 = splice(@l_ids,0,100)){
          wait_for_rate_limit('users_lookup');

          if ($check_block == 1) {
            wait_for_rate_limit('friend_lookup');
          }
          my @unk = users_lookup(@ids_100) ;
        
          if ( $debug == 1 ) {    print Dumper @unk; }
          $teng->bulk_insert( 'unknown' , \@unk ) ;
          
        }


    }


    return  ;
} 

# ====================
sub users_lookup {  # usage: @userinfo = users_lookup(@user_id_list)
    @_ or die "ERROR: users_lookup() : user_id_list is empty\n" ;
    scalar (@_) <= 100 or die "ERROR: users_lookup() : user_id_list > 100\n" ;

    if ($debug == 1) { print " -- lookup call  --\n" ; }
    my $user_id_list = join ',', @_ ;
    my $user_ref;
    my $rel_ref;

    if ($debug == 1) { print " -- lookup call  lookup users--\n" ; }
    eval {
    $user_ref = $twit->lookup_users({ user_id => $user_id_list, 'include_entities' => 'false'  }) ;
    };
    
        if (my $err = $@) { 
                warn "\n when lookup_ids - HTTP Response Code: ", $err->code, "\n",
                "\n - HTTP Message......: ", $err->message, "\n",
                "\n - Twitter error.....: ", $err->error, "\n";
                die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
        }
    
    if ($debug == 1) { print " -- lookup call  lookup friendships--\n" ; }

    if ($check_block == 1) {
      eval {
      $rel_ref = $twit->lookup_friendships({ user_id => $user_id_list }) ;
      };
          if (my $err = $@) { 
                  warn "\n when lookup_friendships - HTTP Response Code: ", $err->code, "\n",
                  "\n - HTTP Message......: ", $err->message, "\n",
                  "\n - Twitter error.....: ", $err->error, "\n";
                  die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
          }
    }
    my $i = 0;
    my %user_ins  ;
    my %user_upd ;
    my @unk_info = ();
    my $ss = "";

 #   $ss =  $rel_ref->[$i]->{'connections'};
    #print "connections =  @{$ss[0]}  \n";
    my $tmp =  "";    ##                           join(",",  @{$ss});
    #if( $debug ==1 ) {print "connections =  $tmp \n" ; }

    foreach  (@$user_ref ) {

        my $id              = $_->{'id'}              // '' ;
        my $screen_name       = $_->{'screen_name'}       // '' ;
=pod
        my $name              = $_->{'name'}              // '' ;
        my $description       = $_->{'description'}       // '' ;
=cut
        my $protected          = $_->{'protected'}        // '' ;  #非公開アカウント
        my $followers_count          = $_->{'followers_count'}        // '' ;
        my $friends_count          = $_->{'following'}        // '' ;
        if ( $protected == 1 ) { $i++; next; }                               # 非公開なら捨てる
    
        if ($check_block == 1) {                                             # ブロック済みかのチェック
            $ss          =   @{$rel_ref}[$i]->{'connections'}        // '' ;            # 関係性

            my $dd = join(",",  @{$ss});
            if ( $debug ==1) {
                print "  ID :   $id \n";
                print "when $dd\n" ;
            }
            if ( $dd =~ /blocking/i ) { $i++; next; }        # block済みなら読み飛ばす
         }
#        $name        =~ s/[\n\r\t]/ /g ;

 #       my $userinfo = "$screen_name" ;
 #       Encode::is_utf8($userinfo) and $userinfo = Encode::encode('utf-8',$userinfo) ;

         %user_ins = (
                             'id'              => $id,
                             'screen_name'     => $screen_name,
                             'protected'       => $protected,
                             'followers_cnt'   => $followers_count,
                             'friends_cnt'     => $friends_count 
        );
        %user_upd = (
                             'screen_name'     => $screen_name,
                             'protected'       => $protected,
                             'followers_cnt'   => $followers_count,
                             'friends_cnt'     => $friends_count 
        );
#        print Dumper $teng;
        my $binds = $teng->insert_or_update('user_ids', \%user_ins, \%user_upd);
   # if( $debug ==1 ) {print "isnert user SQL =  $sql \n" ; }

        #$teng->execute($sql, \@binds);        
        

        push @unk_info, +{
                             'id'              => $id,
                             'screen_name'     => $screen_name,
        };
        $i++;
    
    }
    if ( $@ ) { print "Error $@ \n"; }
    
    return @unk_info ;
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
                 "\n limit is : ", $row->users_lookup_remain ," type is : ", $type ,"\n";
  }


}
