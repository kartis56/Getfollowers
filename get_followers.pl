#!/usr/bin/perl

# Twitter�œ��胆�[�U�̃t�H�����[�ꗗ���擾���A�e�L�X�g�`���ŏo�͂���
#
# Usage:  ./get_followers.pl 
#
# spamer.txt�Ŏw�肵�����[�U(screen_name)�ꗗ�́A�������u���b�N���ȊO�̃t�H�����[�ꗗ���擾����
# �o�͌��ʂ� output.txt
# 
#// cygwin�@��perl -MCPAN -e shell
# cpan install Encode  Net::Twitter::Lite YAML::XS Scalar::Util IO::Handle Data::Dumper
#
#
# ���炩���� https://dev.twitter.com/apps ���o�^���āAOAuth�F�؂ɕK�v��
# consumer_key, consumer_secret, access_token, access_token_secret ���擾���A
# keys.txt�ɋL�ڂ��邱��
#

use warnings ;
use strict ;
use Data::Dumper;
use Net::Twitter::Lite::WithAPIv1_1;

eval 'use Encode ; 1' or              # �����R�[�h�ϊ��A�Ȃ��ꍇ�̓G���[�\��
    die "ERROR : cannot load Encode\n" ;
use YAML::XS        'LoadFile';
use Scalar::Util 'blessed';
use IO::Handle;            #�I�[�g�t���b�V��
use POSIX;
#use DBIx::QueryLog;
use Date::Parse;           #str2time

use lib './lib';
use MyAPP::DB;
use MyApp::DB::Schema;
use DateTime;

open TMP, '>>work.txt' ;

open IN, '<spamer.txt' or die "Error : file can't open spamer.txt\n";



my $debug = 1;
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

my $wait_remain = 1;


STDOUT->autoflush(1);
while (<IN>) {
    print STDERR $_ ,"\n";
    get_followers_list($_);
}

close TMP;
exit ;


=pod
sub get_followers_list{
    # ID���X�g�擾
    my @ids = get_followers($_) ;

}
=cut
# ====================
sub get_followers_list {  # Usage:  get_followers($screen_name) ;
    my %arg ;
    $arg{'screen_name'} = $_[0] ;  # API�d�l�Ƃ��ċ󔒂̏ꍇ�͎����̃t�H�����[�擾�ɂȂ�̂Œ���
    if ($debug == 1) { print " arg ".  $arg{'screen_name'} .' $_0 '. $_[0] ." --\n" ; }
    
    $arg{'cursor'} = -1 ;  # 1�y�[�W�ڂ� -1 ���w��
    my @l_ids ;
    my $ids_ref;
    my $followers_ref;

    eval {

    while ($arg{'cursor'}) { # ��x��5000�܂ł����擾�ł��Ȃ��̂�cursor�����������Ȃ���擾���J��Ԃ�

      if ($debug == 1) { print " -- getfollowers call  --\n" ; }
      wait_for_rate_limit('followers_ids');

      $followers_ref = $twit->followers_ids({%arg});
          
      @l_ids = @{ $followers_ref->{'ids'} };
      $arg{'cursor'} = $followers_ref->{'next_cursor'} ;
      print STDERR "Fetched: ids=", scalar @l_ids, ",next_cursor=$arg{'cursor'}\n" ;

      # ���[�U���X�g�ɕϊ�
      # 100�����Ƃɕ������Ď擾
      TMP->autoflush(1);
      while (my @ids_100 = splice(@l_ids,0,100)){
        wait_for_rate_limit('users_lookup');
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

    $ss =  @{$rel_ref}[$i]->{'connections'};
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
        my $protected          = $_->{'protected'}        // '' ;  #����J�A�J�E���g
        if ( $protected == 1 ) { $i++; next; }
    
        $ss          =   @{$rel_ref}[$i]->{'connections'}        // '' ;            # �֌W��

        my $dd = join(",",  @{$ss});
        if ( $debug ==1) {
            print "when $dd\n" ;
        }
        if ( $dd =~ /blocking/i ) { $i++; next; }        # block�ς݂Ȃ�ǂݔ�΂�

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

=pod
#https://github.com/freebsdgirl/ggautoblocker/blob/master/ggautoblocker.pl  ���R�s�[����
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

=cut
############################## ver 2016/08/10 use $l_limit = $type , "_limit"
############################ APP�s���ɑΉ�
sub wait_for_rate_limit {        #  wait_for_rate_limit( $type ) 
  my $type = shift;
  my $row = $teng->single( 'rate_limit', {id => 1} );

  my $old = str2time($row->lastupdt,'JST');
  print "\$old ". localtime($old) ."\n";
  
  if ( ($old +900) <= time ) {                      #�O��擾��������15���o���Ă���Ȃ�rate_limit���Ď擾����
      do `./get_rate_limit.pl`;                    #�o�b�N�_�b�V�� (Shift+@)
      $row = $teng->single( 'rate_limit', {id => 1} );
  }
  
  my $l_limit = "$type" . "_limit";
  my $l_remain = "$type" . "_remain";
  my $l_reset = "$type" . "_reset";
  
  $wait_remain = $row->$l_remain;
  my $app_remain = $row->app_limit_remain;
  my $time = $row->$l_reset || 0;
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
    $time = $row->$l_reset;
    $wait_remain = $row->$l_remain;
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
  $teng->update( 'rate_limit', {$l_remain => $wait_remain , app_limit_remain  => $app_remain} );  #�Ăяo���x��DB��������炷
  if ( $debug == 1 ) {
    print STDERR "wait_for_rate_limit after Loop: ",  POSIX::strftime( "%Y/%m/%d %H:%M:%S",localtime( $time ) ) ,
                 "\n limit is : ", $row->users_lookup_remain ," type is : ", $type ,"\n";
  }


}
