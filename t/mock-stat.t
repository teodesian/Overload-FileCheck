#!/usr/bin/perl -w

# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck qw(CHECK_IS_FALSE CHECK_IS_TRUE FALLBACK_TO_REAL_OP);

my $current_test = "$0";

my $call_my_stat = 0;
my $last_called_for;
our @FAKE_DIR = qw{/a/b/c /usr/somewhere /home/fake};

ok 1, 'start';

my $stat_result = [ stat($0) ];
is scalar @$stat_result, 13, "call stat unmocked";

my $unmocked_stat_for_perl = [ stat($^X) ];

ok Overload::FileCheck::mock_stat( \&my_stat ), "mock_stat succees";

is $call_my_stat, 0, "my_stat was not called at this point";

$stat_result = [ stat($0) ];
is $call_my_stat, 1, "my_stat is now called" or diag explain $stat_result;

#note explain $stat_result;

my $previous_stat_result = [@$stat_result];

$call_my_stat = 0;
$stat_result  = [ stat(_) ];    # <---- FIXME with the GV check
is $call_my_stat, 0, "my_stat is not called";
is $stat_result, $previous_stat_result,
  "stat is the same as previously mocked";

$stat_result = [ stat(*_) ];
is $call_my_stat, 0, "my_stat is not called";
is $stat_result, $previous_stat_result,
  "stat is the same as previously mocked";

is $last_called_for, $0, q[$0 was the last called to my_stat];
is $previous_stat_result => fake_stat_for_dollar_0(), "previous stat result as mocked";

like(
    dies { [ stat('too.long') ] },
    qr/Stat array should contain/,
    "stat array is too long"
);

is $last_called_for, 'too.long', q[last_called_for too.long];

like(
    dies { [ stat('too.short') ] },
    qr/Stat array should contain/,
    "stat array is too short"
);

like(
    dies { [ stat('evil') ] },

    # hide stat using [s]tat for the lstat test
    qr/Your mocked function for [s]tat should return a [s]tat array/,
    "only returning a scalar is wrong..."
);

foreach my $f (qw{alpha1 alpha2 alpha3}) {
    like(
        dies { [ stat($f) ] },
        qr/Overload::FileCheck - Item [0-9]+ is not numeric/,
        "$f - item is not numeric"
    );
}

foreach my $d (@FAKE_DIR) {
    is [ stat($d) ], stat_for_a_directory(), "stat_for_a_directory - $d";

    ok !-e $d, "directory $d does not exist";
}

is [ stat('fake.binary') ], stat_for_a_binary(), "stat_for_a_binary - 'fake.binary'";
is [ stat('fake.tty') ],    stat_for_a_tty(),    "stat_for_a_tty - 'fake.tty'";
is $last_called_for, 'fake.tty', q[last_called_for fake.tty];

my $expect_stat;
$expect_stat = [ (0) x Overload::FileCheck::STAT_T_MAX() ];    # fresh stat
$expect_stat->[ Overload::FileCheck::ST_DEV() ] = 42;

is [ stat('hash.stat.1') ], $expect_stat, "hash.stat.1";

$expect_stat = [ (0) x Overload::FileCheck::STAT_T_MAX() ];    # fresh stat
$expect_stat->[ Overload::FileCheck::ST_DEV() ]   = 42;
$expect_stat->[ Overload::FileCheck::ST_ATIME() ] = 1520000000;

use Data::Dumper;
print Dumper(stat('hash.stat.2'));

is [ stat('hash.stat.2') ], $expect_stat, "hash.stat.2";
like(
    dies { [ stat('hash.stat.broken') ] },
    qr/Unknown index for stat_t/,
    "using a hash with an unknown key"
);

is [ stat($^X) ], $unmocked_stat_for_perl, q[stat is mocked but $^X should fallback to the regular stat];
is [ stat(_) ], $unmocked_stat_for_perl, q[stat is mocked - using _ on an unmocked file];

# --- END ---
ok Overload::FileCheck::unmock_all_file_checks(), "unmock all";
done_testing;

exit;

sub my_stat {
    my ( $opname, $file_or_handle ) = @_;

    note "=== my_stat is called. Type: ", $opname, " File: ", $file_or_handle;
    ++$call_my_stat;
    $last_called_for = $file_or_handle;    # TODO SV is leaking....

    my $f = $file_or_handle;               # alias to use a shorter name later...

    # return an array ref
    return fake_stat_for_dollar_0() if $f eq $current_test;
    return [ 1 .. 42 ] if $f eq 'too.long';
    return [ 1 .. 4 ]  if $f eq 'too.short';
    return [ 'a', 1 .. 12 ] if $f eq 'alpha1';    # only first letter is alpha
    return [ 1 .. 12, 'z' ] if $f eq 'alpha2';    # only last letter is alpha
    return [ 'a' .. 'm' ] if $f eq 'alpha3';      # all letters are alpha

    return stat_for_a_directory() if grep { $f eq $_ } @FAKE_DIR;
    return stat_for_a_binary()    if $f eq 'fake.binary';
    return stat_for_a_tty()       if $f eq 'fake.tty';

    # can also return a hash (comlete or incomplete at this time)
    return { st_dev => 42 } if $f eq 'hash.stat.1';
    return { st_dev => 42, st_atime => 1520000000 } if $f eq 'hash.stat.2';
    return { st_dev => 42, whatever => 1520000000 } if $f eq 'hash.stat.broken';

    return 666 if $f eq 'evil';

    return FALLBACK_TO_REAL_OP();
}

sub fake_stat_for_dollar_0 {
    return [
        0,
        0,
        4,
        3,
        2,
        1,
        42,
        10001,
        1000,
        2000,
        3000,
        0,
        0
    ];
}

sub stat_for_a_directory {
    return [
        64769,
        67149975,
        16877,
        23,
        0,
        0,
        0,
        4096,
        1539271725,
        1524671853,
        1524671853,
        4096,
        8,
    ];
}

sub stat_for_a_binary {
    return [
        64769,
        33728572,
        33261,
        1,
        0,
        0,
        0,
        28920,
        1539797896,
        1523421302,
        1526572488,
        4096,
        64,
    ];
}

sub stat_for_a_tty {
    return [
        5,
        1043,
        8592,
        1,
        0,
        5,
        1025,
        0,
        1538428544,
        1538428544,
        1538428550,
        4096,
        0,
    ];
}
