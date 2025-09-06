#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 2;
use_ok('Vigil::Crypt');
use_ok('Vigil::QueryString');
