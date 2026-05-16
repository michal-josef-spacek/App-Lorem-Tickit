use strict;
use warnings;

use App::Lorem::Tickit;
use Test::More 'tests' => 10;
use Test::NoWarnings;

# Test.
my $widget = App::Lorem::Tickit::Widget->new('version' => '0.01');
isa_ok($widget, 'App::Lorem::Tickit::Widget');
is($widget->{'_active'}, 'paragraphs', 'Default active setting.');
is($widget->{'_mode'}, 'paragraphs', 'Default generator.');
is($widget->{'_counts'}->{'paragraphs'}, 3, 'Default paragraph count.');
is($widget->{'_counts'}->{'sentences'}, 8, 'Default sentence count.');
is($widget->{'_counts'}->{'words'}, 50, 'Default word count.');

# Test.
$widget->_next_active;
is($widget->{'_active'}, 'sentences', 'Active setting changed to sentences.');

# Test.
$widget->_next_active;
is($widget->{'_active'}, 'words', 'Active setting changed.');

# Test.
$widget->_change_count(1);
is($widget->{'_counts'}->{'words'}, 51, 'Word count increased.');
