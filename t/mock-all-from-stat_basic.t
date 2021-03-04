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

use Overload::FileCheck -from_stat => \&my_stat, qw{:check :stat};
use Carp;

use constant IS_WIN => grep { $^O eq $_ } qw{MSWin32 msys};

my $fake_files = {

    "$0"           => [ stat($0) ],
    'fake.binary'  => stat_as_file( perms => 0755, size => 1000 ),
    'fake.dir'     => stat_as_directory( size => 99 ),
    'zero'         => fake_stat_zero(),
    'regular.file' => stat_as_file( size => 666 ),
    'empty.file'   => stat_as_file(),
};

$fake_files->{'a.symlink'} = stat_as_symlink() unless IS_WIN;
$fake_files->{'my.socket'} = stat_as_socket()  unless IS_WIN;

# move to DATA
foreach my $l (<DATA>) {
    chomp $l;
    if ( $l =~ s{^\s*#}{} ) {
        note $l;
        next;
    }

    #Skip symlink and socket tests on windows, they will die
    next if IS_WIN && $l =~ m/a\.symlink|my\.socket/;
    if (IS_WIN && $l =~ m/-S|-l/) {
        # _ is a special case, we won't re-execute the check and die, just return undef.
        next if $l =~ m/_/;
        
        eval $l;
        like($@, qr/not supported on windows/i, "Checking for symlink or socket on windows dies ($l)");
        next;
    }

    next unless $l =~ qr{^[!-]};
    ok eval $l, $l or diag $@;
}

# some extra check

if ( $] >= 5.016 ) {

    like(
        dies {
            -e 'fake.dir' && !-l _
        },
        qr/\QThe stat preceding -l _ wasn't an lstat\E/,
        "The stat preceding -l _ wasn't an lstat: -e 'fake.dir' && !-l -"
    );

    like(
        dies {
            -e 'regular.file' && !-l _
        },
        qr/\QThe stat preceding -l _ wasn't an lstat\E/,
        "The stat preceding -l _ wasn't an lstat: -e 'fake.dir' && !-l -"
    );

}

done_testing;

exit;

sub my_stat {
    my ( $stat_or_lstat, $f ) = @_;

    #note "=== my_stat is called. Type: ", $stat_or_lstat, " File: ", $f;

    # check if it's mocked
    if ( defined $f && defined $fake_files->{$f} ) {

        #note "fake_file is known for $f";
        return $fake_files->{$f};
    }

    return FALLBACK_TO_REAL_OP();
}

sub fake_stat_zero {
    return [ (0) x 13 ];
}

__DATA__
###
### test data: all lines are tests which are run sequentially
###

# a directory
-e 'fake.dir'
-d 'fake.dir'
!-f 'fake.dir'
!-c 'fake.dir'
!-l 'fake.dir'
!-S 'fake.dir'
!-b 'fake.dir'

# regular file
-e 'regular.file'
-f 'regular.file'
!-d 'regular.file'
!-l 'regular.file'
-s 'regular.file'
!-z 'regular.file'
!-S 'regular.file'
!-b 'regular.file'
!-c 'regular.file'

# a binary
-e 'fake.binary'
-f 'fake.binary'
!-l 'fake.binary'
-x 'fake.binary'
!-S 'fake.binary'
!-d 'fake.binary'

# a symlink
-e 'a.symlink'
!-f 'a.symlink'
-l 'a.symlink'
!-d 'a.symlink'
!-S 'a.symlink'
-z 'a.symlink'

# a Socket
-e 'my.socket'
!-d 'my.socket'
!-f 'my.socket'
-S 'my.socket'
!-s 'my.socket'

# a zero stat
!-e 'zero'
!-f 'zero'
!-l 'zero'
!-d 'zero'
-z 'zero'

# checking _ on a directory
-e 'fake.dir'
-d _
-s _
!-S _
# checking some oneliners
-e 'fake.dir' && -d _
-d 'fake.dir' && -e _
!(-d 'fake.dir' && -f _)
-d 'fake.dir' && !-f _
-d 'fake.dir' && -d _
-e 'fake.dir' && -d _ && -s _


# checking _ on a file
-e 'regular.file'
-f _
!-d _
-s _
!-z _
!-S _
# checking some oneliners
-e 'regular.file' && -f _
-f 'regular.file' && -e _
!( -e 'regular.file' && -d _ )
-e 'regular.file' && !-d _
!-d 'regular.file' && -e _ && -f _
-f 'regular.file' && -f _ && -f _ && -f _ && -f _ && -f _ && -f _ && -f _
