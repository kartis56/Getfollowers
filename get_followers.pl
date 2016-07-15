#!/usr/bin/perl

# Twitter�œ��胆�[�U�̃t�H�����[�ꗗ���擾���A�^�u��؂�e�L�X�g�`���ŏo�͂���
#
# Usage:  ./get_followers.pl  [USER]
#
# USER�iscreen name�j�Ŏw�肵�����[�U�̃t�H�����[�ꗗ���擾����
# �ȗ����͎������g�̃t�H�����[�ꗗ���擾����
# 
#// cygwin�@��perl -MCPAN -e shell
# cpan install Encode inc:latest Net::Twitter::Lite YAML::XS Scalar::Util 
#
#
# ���炩���� https://dev.twitter.com/apps ���o�^���āAOAuth�F�؂ɕK�v��
# consumer_key, consumer_secret, access_token, access_token_secret ���擾���A
# �\�[�X���� twitter_oauth �T�u���[�`�����ɋL�ڂ��邱��
#

use warnings ;
use strict ;
use Data::Dumper;
use Net::Twitter::Lite::WithAPIv1_1;
use File::Spec;
eval 'use Net::Twitter::Lite ; 1' or  # Twitter API�p���W���[���A�Ȃ��ꍇ�̓G���[�\��
	die "ERROR : cannot load Net::Twitter::Lite\n" ;
eval 'use Encode ; 1' or              # �����R�[�h�ϊ��A�Ȃ��ꍇ�̓G���[�\��
	die "ERROR : cannot load Encode\n" ;
use YAML::XS        'LoadFile';
use Scalar::Util 'blessed';
use IO::Handle;			#�I�[�g�t���b�V��

open TMP, '>>work.txt' ;

open IN, '<spamer.txt' or die "Error : file can't open spamer.txt\n";



my $debug = 1;
my $conf         = LoadFile( "keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);



# OAuth�F��
#my $twit ;
#twitter_oauth() ;
#
while (<IN>) {
	print STDERR $_;
	get_followers_list($_);
}

close TMP;
exit ;



sub get_followers_list{
	# ID���X�g�擾
	my @ids = get_followers($_) ;

# ���[�U���X�g�ɕϊ�
# 100�����Ƃɕ������Ď擾
	TMP->autoflush(1);
	while (my @ids_100 = splice(@ids,0,100)){
		wait_for_rate_limit('lookup_users');
	#	wait_for_rate_limit('friendships');
		my @users = users_lookup(@ids_100) ;
		$" = "\r\n" ;
		print TMP "@users\r\n" ;
	}
}

# ====================
sub get_followers {  # Usage: @ids = get_followers($screen_name) ;
	my %arg ;
	$arg{'screen_name'} = $_[0] ;  # API�d�l�Ƃ��ċ󔒂̏ꍇ�͎����̃t�H�����[�擾�ɂȂ�̂Œ���
	if ($debug == 1) { print " arg ".  $arg{'screen_name'} .' $_0 '. $_[0] ." --\n" ; }
	
	$arg{'cursor'} = -1 ;  # 1�y�[�W�ڂ� -1 ���w��
	my @l_ids ;
	my $ids_ref;
	my $followers_ref;

	eval {

	while ($arg{'cursor'}){ # ��x��5000�܂ł����擾�ł��Ȃ��̂�cursor�����������Ȃ���擾���J��Ԃ�

		if ($debug == 1) { print " -- getfollowers call  --\n" ; }
		wait_for_rate_limit('followers');

		$followers_ref = $twit->followers_ids({%arg});
			
		$ids_ref = $followers_ref->{'ids'} ;

		push @l_ids, @$ids_ref ;
		$arg{'cursor'} = $followers_ref->{'next_cursor'} ;
		print STDERR "Fetched: ids=", scalar @$ids_ref, ",next_cursor=$arg{'cursor'}\n" ;
	}

	}; #END of eval
	if (my $err = $@) { 
			die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');

			warn "\n when followers_ids - HTTP Response Code: ", $err->code, "\n",
			"\n - HTTP Message......: ", $err->message, "\n",
			"\n - Twitter error.....: ", $err->error, "\n";
	
	}

	return @l_ids ;
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
				die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
 
				warn "\n when lookup_ids - HTTP Response Code: ", $err->code, "\n",
				"\n - HTTP Message......: ", $err->message, "\n",
				"\n - Twitter error.....: ", $err->error, "\n";
			
		}
	
	if ($debug == 1) { print " -- lookup call  lookup friendships--\n" ; }

	eval {
	$rel_ref = $twit->lookup_friendships({ user_id => $user_id_list }) ;
	};
		if (my $err = $@) { 
				die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');
 
				warn "\n when lookup_friendships - HTTP Response Code: ", $err->code, "\n",
				"\n - HTTP Message......: ", $err->message, "\n",
				"\n - Twitter error.....: ", $err->error, "\n";
			
		}
    my $i = 0;
	my @user_info ;
	my @ss;

	@ss =  @{$rel_ref}[$i]->{'connections'};
	my $tmp =  join(",",  @{$ss[0]});
	if( $debug ==1 ) {print "tmp  " , $tmp , "\n" ; }

	foreach  (@$user_ref ) {

		my $screen_name       = $_->{'screen_name'}       // '' ;
		my $name              = $_->{'name'}              // '' ;
		my $id              = $_->{'id'}              // '' ;
		my $description       = $_->{'description'}       // '' ;
		my $following          = $_->{'following'}        // '' ;
		my $followers_count          = $_->{'followers_count'}        // '' ;
		my $protected          = $_->{'protected'}        // '' ;  #����J�A�J�E���g
		if ( $protected == 1 ) { $i++; next; }
	
		@ss          =   @{$rel_ref}[$i]->{'connections'}        // '' ;			# �֌W��

		my @d =  @{$ss[0]} ;
		my $dd = join(",",  @{$ss[0]});
		if ( $debug ==1) {
			print "connections :". @d . "\n"; 
			print "when $dd\n" ;
		}
		if ( $dd =~ /blocking/i ) { $i++; next; }		# block�ς݂Ȃ�ǂݔ�΂�

		$name        =~ s/[\n\r\t]/ /g ;
		$description =~ s/[\n\r\t]/ /g ;

		my $userinfo = "$screen_name" ;
		Encode::is_utf8($userinfo) and $userinfo = Encode::encode('utf-8',$userinfo) ;

		push @user_info, $userinfo ;
		$i++;
	
	}
	if ( $@ ) { print "Error $@ \n"; }
	
	return @user_info ;
}

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


# ====================
sub wait_for_rate_limit {
	my $type = shift;

	my $limit = get_rate_limit($type);
		if ($debug ==1) { print "wait_for_rate_limit enter ". $limit->{'remaining'} ."\n"; }
		
	my $time = $limit->{'reset'} ;
	
	until ( $limit->{'remaining'} >= 2 ) {
		if ($debug ==1) {
			print STDERR " -- API limit reached in wait_for_limit, waiting for ". ( $time - time ) . " seconds -- type is : ". $type. "\n" ; 
			print "----------------------- At until Loop\n";
		}
		sleep ( $time - time + 1 );
		$limit = get_rate_limit($type);
		$time = $limit->{'reset'} ;
		if ( ($time - time) <= 0 ){		# reset���Â����Ƃ�����
			$time = time + 60; }
		if ($debug ==1) { print STDERR "wait_for_rate_limit next Loop: ". $time . "  limit is : ". $limit->{'remaining'} ." type is : ". $type. "\n"; }
	}

}