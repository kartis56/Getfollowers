drop table if exists  user_ids;
drop table if exists  Blocked;
drop table if exists  Whitelist;
drop table if exists  4R4s;
drop table if exists  Unknown;
drop table if exists  rate_limit;


create table user_ids (
    id varchar(19) primary key, screen_name varchar(16), protected TINYINT default 0,
    followers_cnt int default 0, friends_cnt int default 0, deleted TINYINT default 0, 
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, 
    INDEX idx_name(screen_name), INDEX idx_protect(protected),  INDEX idx_delete(deleted) ) ;
                               
create table Blocked (
    id varchar(19) primary key, done TINYINT default 0,
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ;

create table Whitelist (
    id varchar(19) primary key, screen_name varchar(16), 
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    index white_idx(screen_name) ) ;

create table 4R4s (
    screen_name varchar(16) primary key, id varchar(19) default 0, count int default 0, 
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    index idx_r4s(screen_name) ) ;


create table Unknown (
    screen_name varchar(16),
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    index idx_unk(screen_name) ) ;


create table rate_limit ( 
    id int primary key,
	list_limit int default 15,
	list_remain int default 15,
	list_reset DATETIME,
	list_memberships_limit int default 15,
	list_memberships_remain int default 15,
	list_memberships_reset DATETIME,
	list_members_limit int default 180,
	list_members_remain int default 180,
	list_members_reset DATETIME,
	list_show_limit int default 15,
	list_show_remain int default 15,
	list_show_reset DATETIME,
	list_statuses_limit int default 180,
	list_statuses_remain int default 180,
	list_statuses_reset DATETIME,
	app_limit_limit int default 180,
	app_limit_remain int default 180,
	app_limit_reset DATETIME,
	friend_list_limit int default 200,
	friend_list_remain int default 200,
	friend_list_reset DATETIME,
	friend_lookup_limit int default 15,
	friend_lookup_remain int default 15,
	friend_lookup_reset DATETIME,
	friend_show_limit int default 180,
	friend_show_remain int default 180,
	friend_show_reset DATETIME,
	blocks_list_limit int default 15,
	blocks_list_remain int default 15,
	blocks_list_reset DATETIME,
	blocks_ids_limit int default 15,
	blocks_ids_remain int default 15,
	blocks_ids_reset DATETIME,
	users_r4s_limit int default 15,
	users_r4s_remain int default 15,
	users_r4s_reset DATETIME,
	users_search_limit int default 180,
	users_search_remain int default 180,
	users_search_reset DATETIME,
	users_lookup_limit int default 180,
	users_lookup_remain int default 180,
	users_lookup_reset DATETIME,
	followers_ids_limit int default 15,
	followers_ids_remain int default 15,
	followers_ids_reset DATETIME,
	followers_list_limit int default 15,
	followers_list_remain int default 15,
	followers_list_reset DATETIME,
	friends_follow_ids_limit int default 15,
	friends_follow_ids_remain int default 15,
	friends_follow_ids_reset DATETIME,
	friends_follow_list_limit int default 15,
	friends_follow_list_remain int default 15,
	friends_follow_list_reset DATETIME,
	friends_list_limit int default 15,
	friends_list_remain int default 15,
	friends_list_reset DATETIME,
	friends_ids_limit int default 15,
	friends_ids_remain int default 15,
	friends_ids_reset DATETIME,
    lastupdt DATETIME default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) ;

