package MyApp::DB;
use strict;
use warnings;
use parent "Teng";
#use parent "SQL::Maker";

__PACKAGE__->load_plugin('+Teng::Plugin::FindOrCreate');
__PACKAGE__->load_plugin(qw/Count/);
__PACKAGE__->load_plugin('InsertOrUpdate');    # Teng
1;
