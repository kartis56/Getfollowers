package MyApp::DB;
use strict;
use warnings;
use parent "Teng";

__PACKAGE__->load_plugin('+Teng::Plugin::FindOrCreate');
__PACKAGE__->load_plugin(qw/Count/);
__PACKAGE__->load_plugin('+SQL::Maker::Plugin::InsertOnDuplicate');    # SQLMaker
1;
