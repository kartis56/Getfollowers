#!/usr/bin/perl

# Twitter�Ŏ����̃u���b�N�ς�id�ꗗ���擾���A�e�L�X�g�`���ŏo�͂���
#
# Usage:  ./get_blocked.pl  
#
# 
#// cygwin�@��perl -MCPAN -e shell
# cpan install Encode inc:latest Net::Twitter::Lite YAML::XS Scalar::Util 
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
use File::Spec;
eval 'use Net::Twitter::Lite ; 1' or  # Twitter API�p���W���[���A�Ȃ��ꍇ�̓G���[�\��
	die "ERROR : cannot load Net::Twitter::Lite\n" ;
eval 'use Encode ; 1' or              # �����R�[�h�ϊ��A�Ȃ��ꍇ�̓G���[�\��
	die "ERROR : cannot load Encode\n" ;
use YAML::XS        'LoadFile';
use Scalar::Util 'blessed';
use IO::Handle;			#�I�[�g�t���b�V��

open TMP, '>>blocking.txt' ;


my $debug = 1;
my $conf         = LoadFile( "../keys.txt" );
my %creds        = %{$conf->{creds}};
my $twit = Net::Twitter::Lite::WithAPIv1_1->new(%creds);


	 get_blocks_list();


close TMP;
exit ;



# ====================
sub get_blocks_list {  # Usage: get_blocks_list ;
	my %arg ;
	
	$arg{'cursor'} = -1 ;  # 1�y�[�W�ڂ� -1 ���w��
#	$arg{'skip_status'} = "true";  # ����Tw���擾���Ȃ�
#	$arg{'include_entities'} = "false";  # entitiy�����Ȃ�

	my @l_ids ;
	my $ids_ref;
	my $blocks_ref;

		if ($debug == 1) { print "next_cursor = $arg{'cursor'}\n" ; }
    
	eval {

	TMP->autoflush(1);
	while ($arg{'cursor'}){ # ��x��5000�܂ł����擾�ł��Ȃ��̂�cursor�����������Ȃ���擾���J��Ԃ�

		if ($debug == 1) { print " -- get_blocks_ids call  --\n" ; }
		wait_for_rate_limit('blocks');

		$blocks_ref = $twit->blocking_ids( {%arg} );
		$ids_ref = $blocks_ref->{'ids'} ;

		@l_ids = @{$ids_ref} ;
		$arg{'cursor'} = $blocks_ref->{'next_cursor'} ;
		print STDERR "Fetched: users=",  scalar( @$ids_ref ), ", next_cursor = $arg{'cursor'}\n" ;
			
# �o��
		
	my @users =  join "\r\n", @l_ids;
	#	my @users = print_blocks_list( @l_ids ) ;
	#	$" = "\r\n" ;
		print TMP "@users\r\n" ;
#�o�͂����

	}

	}; #END of eval
	if (my $err = $@) { 
			die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::WithAPIv1_1::Error');

			warn "\n when blocks_ids - HTTP Response Code: ", $err->code, "\n",
			"\n - HTTP Message......: ", $err->message, "\n",
			"\n - Twitter error.....: ", $err->error, "\n";
	
	}

	return ;
} 
=pod
# ====================
sub print_blocks_list {  # usage:  @userinfo = print_blocks_list(@user_list)
	@_ or die "ERROR: print_blocks_list() : user_id_list is empty\n" ;
#	scalar (@_) <= 100 or die "ERROR: print_blocks_list() : user_id_list > 100\n" ;

	if ($debug == 1) { print " -- print_blocks_list call  --\n" ; }
#	my $user_id_list
	my $user_ref =  join ',', @_ ;
	my @user_info ;

#print $user_ref;
	foreach  ( \$user_ref ) {

		my $id              = $_->{'ids'}              // '' ;

		my $userinfo =  qw/$id/;  
		my $screen_name       = $_->{'screen_name'}       // '' ;
		my $protected          = $_->{'protected'}        // '' ;  #����J�A�J�E���g
		my $followers_count          = $_->{'followers_count'}        // '' ;
		my $friends_count          = $_->{'friends_count'}        // '' ;
		my $following          = $_->{'following'}        // '' ;  #�t�H���[�ς݃A�J�E���g
		my $blocking          = $_->{'blocking'}        // '' ;  #�u���b�N�ς݃A�J�E���g
		if ( $following =~ /following/i ) {  next; }		# �t�H���[�ς݂Ȃ�ǂݔ�΂�


#		Encode::is_utf8($userinfo) and $userinfo = Encode::encode('utf-8',$userinfo) ;

		push @user_info, $user_ref ;
	
	#}
	if ( $@ ) { print "Error $@ \n"; }
	
	return @user_info ;
}
=cut

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
		

	if ( $type =~ /blocks/ ) {
		print "blocks_ids remaining ,". $m->{'resources'}->{'blocks'}->{'/blocks/ids'}->{'remaining'} ."  \n";
		return { 
			type => $type,
			remaining => $m->{'resources'}->{'blocks'}->{'/blocks/ids'}->{'remaining'}, 
			reset => $m->{'resources'}->{'blocks'}->{'/blocks/ids'}->{'reset'} 
		};
	} else {
=pod
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
=cut
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
