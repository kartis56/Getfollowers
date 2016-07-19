drop table if exists  user_ids;
drop table if exists  Blocked;
drop table if exists  follower_ids;
drop table if exists  rate_limit;
drop table if exists  Unknown;


create table user_ids (
    id varchar(19) primary key, screen_name varchar(16), protected TINYINT default false,
    followers_cnt int default 0, friends_cnt int default 0, deleted TINYINT default false, 
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, 
    INDEX idx_name(screen_name), INDEX idx_protect(protected),  INDEX idx_delete(deleted) ) ;
                               
create table Blocked (
    id varchar(19) primary key, 
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ;

create table follower_ids (
    id varchar(19) primary key, count int,
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    index flw_idx(count) ) ;

create table Unknown (
    screen_name varchar(16),
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    index idx_unk(screen_name) ) ;


create table rate_limit ( 
	list_limit int default 15,
	list_remain int default 15,
	list_reset varchar(11),
	list_memberships_limit int default 15,
	list_memberships_remain int default 15,
	list_memberships_reset varchar(11),
	list_members_limit int default 180,
	list_members_remain int default 180,
	list_members_reset varchar(11),
	list_show_limit int default 15,
	list_show_remain int default 15,
	list_show_reset varchar(11),
	list_statuses_limit int default 180,
	list_statuses_remain int default 180,
	list_statuses_reset varchar(11),
	app_limit_limit int default 180,
	app_limit_remain int default 180,
	app_limit_reset varchar(11),
	friend_list_limit int default 200,
	friend_list_remain int default 200,
	friend_list_reset varchar(11),
	friend_lookup_limit int default 15,
	friend_lookup_remain int default 15,
	friend_lookup_reset varchar(11),
	friend_show_limit int default 180,
	friend_show_remain int default 180,
	friend_show_reset varchar(11),
	blocks_list_limit int default 15,
	blocks_list_remain int default 15,
	blocks_list_reset varchar(11),
	blocks_ids_limit int default 15,
	blocks_ids_remain int default 15,
	blocks_ids_reset varchar(11),
	users_r4s_limit int default 15,
	users_r4s_remain int default 15,
	users_r4s_reset varchar(11),
	users_search_limit int default 180,
	users_search_remain int default 180,
	users_search_reset varchar(11),
	users_lookup_limit int default 180,
	users_lookup_remain int default 180,
	users_lookup_reset varchar(11),
	followers_ids_limit int default 15,
	followers_ids_remain int default 15,
	followers_ids_reset varchar(11),
	followers_list_limit int default 15,
	followers_list_remain int default 15,
	followers_list_reset varchar(11),
	friends_follow_ids_limit int default 15,
	friends_follow_ids_remain int default 15,
	friends_follow_ids_reset varchar(11),
	friends_follow_list_limit int default 15,
	friends_follow_list_remain int default 15,
	friends_follow_list_reset varchar(11),
	friends_list_limit int default 15,
	friends_list_remain int default 15,
	friends_list_reset varchar(11),
	friends_ids_limit int default 15,
	friends_ids_remain int default 15,
	friends_ids_reset varchar(11),
    lastupdt DATETIME default CURRENT_DATETIME ON UPDATE CURRENT_DATETIME) ;

