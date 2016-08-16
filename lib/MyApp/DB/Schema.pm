package MyApp::DB::Schema;
use strict;
use warnings;
use Teng::Schema::Declare;
table {
    name '4R4s';
    pk 'screen_name';
    columns (
        {name => 'screen_name', type => 12},
        {name => 'id', type => 12},
        {name => 'count', type => 4},
        {name => 'lastupdt', type => 11},
    );
};

table {
    name 'Blocked';
    pk 'id';
    columns (
        {name => 'id', type => 12},
        {name => 'done', type => 4},
        {name => 'lastupdt', type => 11},
    );
};

table {
    name 'Whitelist';
    pk 'id';
    columns (
        {name => 'id', type => 12},
        {name => 'screen_name', type => 12},
        {name => 'lastupdt', type => 11},
    );
};

table {
    name 'foo';
    pk ;
    columns (
        {name => 'id', type => 4},
        {name => 'name', type => 12},
    );
};

table {
    name 'rate_limit';
    pk 'id';
    columns (
        {name => 'id', type => 4},
        {name => 'list_limit', type => 4},
        {name => 'list_remain', type => 4},
        {name => 'list_reset', type => 11},
        {name => 'list_memberships_limit', type => 4},
        {name => 'list_memberships_remain', type => 4},
        {name => 'list_memberships_reset', type => 11},
        {name => 'list_members_limit', type => 4},
        {name => 'list_members_remain', type => 4},
        {name => 'list_members_reset', type => 11},
        {name => 'list_show_limit', type => 4},
        {name => 'list_show_remain', type => 4},
        {name => 'list_show_reset', type => 11},
        {name => 'list_statuses_limit', type => 4},
        {name => 'list_statuses_remain', type => 4},
        {name => 'list_statuses_reset', type => 11},
        {name => 'app_limit_limit', type => 4},
        {name => 'app_limit_remain', type => 4},
        {name => 'app_limit_reset', type => 11},
        {name => 'friend_list_limit', type => 4},
        {name => 'friend_list_remain', type => 4},
        {name => 'friend_list_reset', type => 11},
        {name => 'friend_lookup_limit', type => 4},
        {name => 'friend_lookup_remain', type => 4},
        {name => 'friend_lookup_reset', type => 11},
        {name => 'friend_show_limit', type => 4},
        {name => 'friend_show_remain', type => 4},
        {name => 'friend_show_reset', type => 11},
        {name => 'blocks_list_limit', type => 4},
        {name => 'blocks_list_remain', type => 4},
        {name => 'blocks_list_reset', type => 11},
        {name => 'blocks_ids_limit', type => 4},
        {name => 'blocks_ids_remain', type => 4},
        {name => 'blocks_ids_reset', type => 11},
        {name => 'users_r4s_limit', type => 4},
        {name => 'users_r4s_remain', type => 4},
        {name => 'users_r4s_reset', type => 11},
        {name => 'users_search_limit', type => 4},
        {name => 'users_search_remain', type => 4},
        {name => 'users_search_reset', type => 11},
        {name => 'users_lookup_limit', type => 4},
        {name => 'users_lookup_remain', type => 4},
        {name => 'users_lookup_reset', type => 11},
        {name => 'followers_ids_limit', type => 4},
        {name => 'followers_ids_remain', type => 4},
        {name => 'followers_ids_reset', type => 11},
        {name => 'followers_list_limit', type => 4},
        {name => 'followers_list_remain', type => 4},
        {name => 'followers_list_reset', type => 11},
        {name => 'friends_follow_ids_limit', type => 4},
        {name => 'friends_follow_ids_remain', type => 4},
        {name => 'friends_follow_ids_reset', type => 11},
        {name => 'friends_follow_list_limit', type => 4},
        {name => 'friends_follow_list_remain', type => 4},
        {name => 'friends_follow_list_reset', type => 11},
        {name => 'friends_list_limit', type => 4},
        {name => 'friends_list_remain', type => 4},
        {name => 'friends_list_reset', type => 11},
        {name => 'friends_ids_limit', type => 4},
        {name => 'friends_ids_remain', type => 4},
        {name => 'friends_ids_reset', type => 11},
        {name => 'lastupdt', type => 11},
    );

            use Date::Parse;
            use DateTime;
            use POSIX;
        inflate qr/.+_reset/ => sub {
            my ($col_value) = @_;
            return str2time($col_value,'JST');
        };
        deflate qr/.+_reset/ => sub {
            my ($col_value) = @_;
            return  strftime("%Y-%m-%d %H:%M:%S" , localtime( $col_value));
        };
    };

table {
    name 'unknown';
    pk ;
    columns (
        {name => 'id', type => 12},
        {name => 'screen_name', type => 12},
        {name => 'lastupdt', type => 11},
    );
};

table {
    name 'user_ids';
    pk 'id';
    columns (
        {name => 'id', type => 12},
        {name => 'screen_name', type => 12},
        {name => 'protected', type => 4},
        {name => 'followers_cnt', type => 4},
        {name => 'friends_cnt', type => 4},
        {name => 'deleted', type => 4},
        {name => 'lastupdt', type => 11},
    );
};

1;

