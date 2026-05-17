use strict;
use warnings;

use App::Lorem::Tickit;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($App::Lorem::Tickit::VERSION, 0.02, 'Version.');
