#!/usr/bin/perl

# get_rate_limit
#
# Usage:  ./get_rate_limit.pl
#
# 
#// cygwin　でperl -MCPAN -e shell
# cpan install Encode Net::Twitter::Lite YAML::XS Scalar::Util Data::Dumper DBI DBD::mysql Teng lib
#
#
# あらかじめ https://dev.twitter.com/apps より登録して、OAuth認証に必要な
# consumer_key, consumer_secret, access_token, access_token_secret を取得し、
# ../keys.txtに記載すること
# ../accessKey にDB、host,user,passwdを記載すること



use warnings ;
use strict ;
use Data::Dumper;
use Net::Twitter::Lite::WithAPIv1_1;
eval 'use Net::Twitter::Lite ; 1' or  # Twitter API用モジュール、ない場合はエラー表示
	die "ERROR : cannot load Net::Twitter::Lite\n" ;
use YAML::XS      ;
use Scalar::Util 'blessed';
use DBI;
use DBD::mysql;
#use Teng;
#use Teng::Schema::Loader;
use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;

my $debug = 1;
my $conf         = YAML::XS::LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);


	my $m ;
	
	my $err ;
	do {
		eval{
			$m = $twit->rate_limit_status    or die 'Error rate_limit_status';
		};
		print "App remaining  $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'}   \n";
	
		if ( $err = $@ ) {

			if ( $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'} == 0 ) {
				if ($debug ==1) {
					print "Zero remaining  $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'} \n"; 
					print " -- API limit reached, waiting for  ( $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'reset'} - time )  seconds --\n" ;
				}
				
				sleep ( $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'reset'} - time + 1 );
			}
 
			warn "when get_rate_limit  - HTTP Response Code:  $err->code \n",
			"\n - HTTP Message......: ", $err->message, "\n",
			"\n - Twitter error.....: ", $err->error, "\n";
		
		}  # end $err 
	
	} while ( $err );
	if ( $debug == 1)  { warn Dumper   $m ; }



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
     schema_class => 'MyApp::DB::Schema', ) or die "connect Eroor";

  my $row = $teng->single_by_sql ( q{select * from rate_limit}   ) ;
  if ($debug == 1) { warn Dumper   $row->get_columns ; }
  
  $teng->update( 'rate_limit',
  +{ 
    list_limit => $m->{'resources'}->{'lists'}->{'/lists/list'}->{'limit'} ,
    list_remain => $m->{'resources'}->{'lists'}->{'/lists/list'}->{'remaining'} ,
    list_reset => $m->{'resources'}->{'lists'}->{'/lists/list'}->{'reset'} ,
    list_memberships_limit => $m->{'resources'}->{'lists'}->{'/lists/memberships'}->{'limit'} ,
    list_memberships_remain => $m->{'resources'}->{'lists'}->{'/lists/memberships'}->{'remaining'} ,
    list_memberships_reset => $m->{'resources'}->{'lists'}->{'/lists/memberships'}->{'reset'} ,
    list_members_limit => $m->{'resources'}->{'lists'}->{'/lists/members'}->{'limit'} ,
    list_members_remain => $m->{'resources'}->{'lists'}->{'/lists/members'}->{'remaining'} ,
    list_members_reset => $m->{'resources'}->{'lists'}->{'/lists/members'}->{'reset'} ,
    list_show_limit => $m->{'resources'}->{'lists'}->{'/lists/show'}->{'limit'} ,
    list_show_remain =>  $m->{'resources'}->{'lists'}->{'/lists/show'}->{'remaining'} ,
    list_show_reset =>  $m->{'resources'}->{'lists'}->{'/lists/show'}->{'reset'} ,
    list_statuses_limit =>  $m->{'resources'}->{'lists'}->{'/lists/statuses'}->{'limit'} ,
    list_statuses_remain =>  $m->{'resources'}->{'lists'}->{'/lists/statuses'}->{'remaining'} ,
    list_statuses_reset =>  $m->{'resources'}->{'lists'}->{'/lists/statuses'}->{'reset'} ,
    app_limit_limit => $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'limit'} ,
    app_limit_remain => $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'} ,
    app_limit_reset => $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'reset'} ,
    friend_list_limit => $m->{'resources'}->{'friendships'}->{'/friendships/list'}->{'limit'} ,
    friend_list_remain => $m->{'resources'}->{'friendships'}->{'/friendships/list'}->{'remaining'} ,
    friend_list_reset => $m->{'resources'}->{'friendships'}->{'/friendships/list'}->{'reset'} ,
    friend_lookup_limit => $m->{'resources'}->{'friendships'}->{'/friendships/lookup'}->{'limit'} ,
    friend_lookup_remain => $m->{'resources'}->{'friendships'}->{'/friendships/lookup'}->{'remaining'} ,
    friend_lookup_reset => $m->{'resources'}->{'friendships'}->{'/friendships/lookup'}->{'reset'} ,
    friend_show_limit => $m->{'resources'}->{'friendships'}->{'/friendships/show'}->{'limit'} ,
    friend_show_remain => $m->{'resources'}->{'friendships'}->{'/friendships/show'}->{'remaining'} ,
    friend_show_reset => $m->{'resources'}->{'friendships'}->{'/friendships/show'}->{'reset'} ,
    blocks_list_limit => $m->{'resources'}->{'blocks'}->{'/blocks/list'}->{'limit'} ,
    blocks_list_remain => $m->{'resources'}->{'blocks'}->{'/blocks/list'}->{'remaining'} ,
    blocks_list_reset => $m->{'resources'}->{'blocks'}->{'/blocks/list'}->{'reset'} ,
    blocks_ids_limit => $m->{'resources'}->{'blocks'}->{'/blocks/ids'}->{'limit'} ,
    blocks_ids_remain => $m->{'resources'}->{'blocks'}->{'/blocks/ids'}->{'remaining'} ,
    blocks_ids_reset => $m->{'resources'}->{'blocks'}->{'/blocks/ids'}->{'reset'} ,
    users_r4s_limit => $m->{'resources'}->{'users'}->{'/users/report_spam'}->{'limit'} ,
    users_r4s_remain => $m->{'resources'}->{'users'}->{'/users/report_spam'}->{'remaining'} ,
    users_r4s_reset => $m->{'resources'}->{'users'}->{'/users/report_spam'}->{'reset'} ,
    users_search_limit => $m->{'resources'}->{'users'}->{'/users/search'}->{'limit'} ,
    users_search_remain => $m->{'resources'}->{'users'}->{'/users/search'}->{'remaining'} ,
    users_search_reset => $m->{'resources'}->{'users'}->{'/users/search'}->{'reset'} ,
    users_lookup_limit => $m->{'resources'}->{'users'}->{'/users/lookup'}->{'limit'} ,
    users_lookup_remain => $m->{'resources'}->{'users'}->{'/users/lookup'}->{'remaining'} ,
    users_lookup_reset => $m->{'resources'}->{'users'}->{'/users/lookup'}->{'reset'} ,
    followers_ids_limit => $m->{'resources'}->{'followers'}->{'/followers/ids'}->{'limit'} ,
    followers_ids_remain => $m->{'resources'}->{'followers'}->{'/followers/ids'}->{'remaining'} ,
    followers_ids_reset => $m->{'resources'}->{'followers'}->{'/followers/ids'}->{'reset'} ,
    followers_list_limit => $m->{'resources'}->{'followers'}->{'/followers/list'}->{'limit'} ,
    followers_list_remain => $m->{'resources'}->{'followers'}->{'/followers/list'}->{'remaining'} ,
    followers_list_reset => $m->{'resources'}->{'followers'}->{'/followers/list'}->{'reset'} ,
    friends_follow_ids_limit => $m->{'resources'}->{'friends'}->{'/friends/following/ids'}->{'limit'} ,
    friends_follow_ids_remain => $m->{'resources'}->{'friends'}->{'/friends/following/ids'}->{'remaining'} ,
    friends_follow_ids_reset => $m->{'resources'}->{'friends'}->{'/friends/following/ids'}->{'reset'} ,
    friends_follow_list_limit => $m->{'resources'}->{'friends'}->{'/friends/following/list'}->{'limit'} ,
    friends_follow_list_remain => $m->{'resources'}->{'friends'}->{'/friends/following/list'}->{'remaining'} ,
    friends_follow_list_reset => $m->{'resources'}->{'friends'}->{'/friends/following/list'}->{'reset'} ,
    friends_list_limit => $m->{'resources'}->{'friends'}->{'/friends/list'}->{'limit'} ,
    friends_list_remain => $m->{'resources'}->{'friends'}->{'/friends/list'}->{'remaining'} ,
    friends_list_reset => $m->{'resources'}->{'friends'}->{'/friends/list'}->{'reset'} ,
    friends_ids_limit => $m->{'resources'}->{'friends'}->{'/friends/ids'}->{'limit'} ,
    friends_ids_remain => $m->{'resources'}->{'friends'}->{'/friends/ids'}->{'remaining'} ,
    friends_ids_reset => $m->{'resources'}->{'friends'}->{'/friends/ids'}->{'reset'} 

  
  
  });


exit ;

