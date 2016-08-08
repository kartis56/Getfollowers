#!/usr/bin/perl

# Twitterで特定ユーザのフォロワー一覧を取得し、テキスト形式で出力する
#
# Usage:  ./get_followers.pl 
#
# spamer.txtで指定したユーザ(screen_name)一覧の、自分がブロック中以外のフォロワー一覧を取得する
# 出力結果は output.txt
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

open TMP, '>>work.txt' ;

open IN, '<spamer.txt' or die "Error : file can't open spamer.txt\n";



my $debug = 1;
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);



# OAuth認証
#my $twit ;
#twitter_oauth() ;
#
STDOUT->autoflush(1);
while (<IN>) {
    print STDERR $_ ,"\n";
    get_followers_list($_);
}

close TMP;
exit ;


=pod
sub get_followers_list{
    # IDリスト取得
    my @ids = get_followers($_) ;

}
=cut
# ====================
sub get_followers_list {  # Usage:  get_followers($screen_name) ;
    my %arg ;
    $arg{'screen_name'} = $_[0] ;  # API仕様として空白の場合は自分のフォロワー取得になるので注意
    if ($debug == 1) { print " arg ".  $arg{'screen_name'} .' $_0 '. $_[0] ." --\n" ; }
    
    $arg{'cursor'} = -1 ;  # 1ページ目は -1 を指定
    my @l_ids ;
    my $ids_ref;
    my $followers_ref;

    eval {

    while ($arg{'cursor'}){ # 一度に5000までしか取得できないのでcursorを書き換えながら取得を繰り返す

        if ($debug == 1) { print " -- getfollowers call  --\n" ; }
        wait_for_rate_limit('followers');

        $followers_ref = $twit->followers_ids({%arg});
            
        $ids_ref = $followers_ref->{'ids'} ;

        @l_ids = @{$ids_ref} ;
        $arg{'cursor'} = $followers_ref->{'next_cursor'} ;
        print STDERR "Fetched: ids=", scalar @$ids_ref, ",next_cursor=$arg{'cursor'}\n" ;

        # ユーザリストに変換
        # 100件ごとに分割して取得
        TMP->autoflush(1);
        while (my @ids_100 = splice(@l_ids,0,100)){
          wait_for_rate_limit('lookup_users');
          my @users = users_lookup(@ids_100) ;
          $" = "\r\n" ;
          print TMP "@users\r\n" ;
        }

    }

    }; #END of eval
    if (my $err = $@) { 
            warn "\n when followers_ids - HTTP Response Code: ", $err->code, "\n",
            "\n - HTTP Message......: ", $err->message, "\n",
            "\n - Twitter error.....: ", $err->error, "\n";
            die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
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
    $user_ref = $twit->lookup_users({ user_id => $user_id_list }) ;
    };
    
        if (my $err = $@) { 
                warn "\n when lookup_ids - HTTP Response Code: ", $err->code, "\n",
                "\n - HTTP Message......: ", $err->message, "\n",
                "\n - Twitter error.....: ", $err->error, "\n";
                die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
        }
    
    if ($debug == 1) { print " -- lookup call  lookup friendships--\n" ; }

    eval {
    $rel_ref = $twit->lookup_friendships({ user_id => $user_id_list }) ;
    };
        if (my $err = $@) { 
                warn "\n when lookup_friendships - HTTP Response Code: ", $err->code, "\n",
                "\n - HTTP Message......: ", $err->message, "\n",
                "\n - Twitter error.....: ", $err->error, "\n";
                die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
        }
    my $i = 0;
    my @user_info ;
    my $ss;

    $ss =  $rel_ref->[$i]->{'connections'};
    #print "connections =  @{$ss[0]}  \n";
    my $tmp =  join(",",  @{$ss});
    if( $debug ==1 ) {print "connections =  $tmp \n" ; }

    foreach  (@$user_ref ) {

        my $screen_name       = $_->{'screen_name'}       // '' ;
=pod
        my $name              = $_->{'name'}              // '' ;
        my $id              = $_->{'id'}              // '' ;
        my $description       = $_->{'description'}       // '' ;
        my $following          = $_->{'following'}        // '' ;
        my $followers_count          = $_->{'followers_count'}        // '' ;
=cut
        my $protected          = $_->{'protected'}        // '' ;  #非公開アカウント
        if ( $protected == 1 ) { $i++; next; }
    
        $ss          =   @{$rel_ref}[$i]->{'connections'}        // '' ;            # 関係性

        my $dd = join(",",  @{$ss});
        if ( $debug ==1) {
            print "when $dd\n" ;
        }
        if ( $dd =~ /blocking/i ) { $i++; next; }        # block済みなら読み飛ばす

#        $name        =~ s/[\n\r\t]/ /g ;
#        $description =~ s/[\n\r\t]/ /g ;

        my $userinfo = "$screen_name" ;
        Encode::is_utf8($userinfo) and $userinfo = Encode::encode('utf-8',$userinfo) ;

        push @user_info, $userinfo ;
        $i++;
    
    }
    if ( $@ ) { print "Error $@ \n"; }
    
    return @user_info ;
}

#https://github.com/freebsdgirl/ggautoblocker/blob/master/ggautoblocker.pl  よりコピー改変
# ====================
sub get_rate_limit {
    my $type = shift;
    my $m ;
    
    eval{
        $m = $twit->rate_limit_status;
        print "App remaining ,". $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'} ."  \n";
    };

    if ( my $err = $@ ) {

        if ( $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'} == 0 ) {
            if ($debug ==1) {
                print "Zero remaining ". $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'remaining'} ."\n"; 
                print " -- API limit reached, waiting for ". ( $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'reset'} - time ) . " seconds --\n" ;
            }
            
            sleep ( $m->{'resources'}->{'application'}->{'/application/rate_limit_status'}->{'reset'} - time + 1 );
        }
 
        warn "when get_rate_limit  - HTTP Response Code: ", $err->code, "\n",
        "\n - HTTP Message......: ", $err->message, "\n",
        "\n - Twitter error.....: ", $err->error, "\n";
        
    }  # end $err 
        

    if ( $type =~ /followers/ ) {
        print "followers remaining ,". $m->{'resources'}->{'followers'}->{'/followers/ids'}->{'remaining'} ."  \n";
        return { 
            type => $type,
            remaining => $m->{'resources'}->{'followers'}->{'/followers/ids'}->{'remaining'}, 
            reset => $m->{'resources'}->{'followers'}->{'/followers/ids'}->{'reset'} 
        };
    } else {
    #if ( $type =~ /lookup_users/ ) {
        my $user_look_rem;
        my $friend_look_rem;
        
        $user_look_rem = $m->{'resources'}->{'users'}->{'/users/lookup'}->{'remaining'};
        $friend_look_rem =  $m->{'resources'}->{'friendships'}->{'/friendships/lookup'}->{'remaining'};
        
        print "lookup_users remaining ,". $user_look_rem ."  \n";
        print "follwers_ids remaining ,". $friend_look_rem ."  \n";

        if( $user_look_rem  >= $friend_look_rem  ) {
            return {
                type => $type, 
                remaining => $friend_look_rem,
                reset => $m->{'resources'}->{'friendships'}->{'/friendships/lookup'}->{'reset'}
            };
        } else {
            return {
                type => $type, 
                remaining => $user_look_rem,
                reset => $m->{'resources'}->{'users'}->{'/users/lookup'}->{'reset'}
            };
        }
    }

}


# ====================
sub wait_for_rate_limit {
    my $type = shift;

    my $limit = get_rate_limit($type);
        if ($debug ==1) { print "wait_for_rate_limit enter ". $limit->{'remaining'} ."\n"; }
        
    my $time = $limit->{'reset'} ;
    
    while ( $limit->{'remaining'} <= 2 ) {
        if ($debug ==1) {
            print STDERR " -- API limit reached in wait_for_limit, waiting for ". ( $time - time ) . " seconds -- type is : ". $type. "\n" ; 
            print "----------------------- At until Loop\n";
        }
        sleep ( $time - time + 1 );
        $limit = get_rate_limit($type);
        $time = $limit->{'reset'} ;
        if ( ($time - time) <= 0 ){ $time = time + 60; }        # resetが古いことがある

        if ($debug ==1) { print STDERR "wait_for_rate_limit next Loop: ". $time . "  limit is : ". $limit->{'remaining'} ." type is : ". $type. "\n"; }
    }

}
