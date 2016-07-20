package MyApp::DB;
use strict;
use warnings;
use parent "Teng";

__PACKAGE__->load_plugin('+Teng::Plugin::FindOrCreate');
1;
