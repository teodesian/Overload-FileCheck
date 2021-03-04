# NAME

Overload::FileCheck - override/mock perl file check -X: -e, -f, -d, ...

# VERSION

version 0.011

# SYNOPSIS

Overload::FileCheck provides a way to mock one or more file checks.
It is also possible to mock stat/lstat functions using ["mock\_all\_from\_stat"](#mock_all_from_stat) and let Overload::FileCheck
mock for you for any other -X checks.

By using mock\_all\_file\_checks you can set a hook function to reply any -X check.

```perl
#!perl

use strict;
use warnings;

use strict;
use warnings;

use Test::More;
use Overload::FileCheck q{:all};

my @exist     = qw{cherry banana apple};
my @not_there = qw{not-there missing-file};

mock_all_file_checks( \&my_custom_check );

sub my_custom_check {
    my ( $check, $f ) = @_;

    if ( $check eq 'e' || $check eq 'f' ) {
        return CHECK_IS_TRUE  if grep { $_ eq $f } @exist;
        return CHECK_IS_FALSE if grep { $_ eq $f } @not_there;
    }

    return CHECK_IS_FALSE if $check eq 'd' && grep { $_ eq $f } @exist;

    # fallback to the original Perl OP
    return FALLBACK_TO_REAL_OP;
}

foreach my $f (@exist) {
    ok( -e $f,  "-e $f is true" );
    ok( -f $f,  "-f $f is true" );
    ok( !-d $f, "-d $f is false" );
}

foreach my $f (@not_there) {
    ok( !-e $f, "-e $f is false" );
    ok( !-f $f, "-f $f is false" );
}

unmock_all_file_checks();

done_testing;
```

# DESCRIPTION

Overload::FileCheck provides a hook system to mock Perl filechecks OPs

[![](https://github.com/CpanelInc/Overload-FileCheck/workflows/linux/badge.svg)](https://github.com/CpanelInc/Overload-FileCheck/actions) [![](https://github.com/CpanelInc/Overload-FileCheck/workflows/macos/badge.svg)](https://github.com/CpanelInc/Overload-FileCheck/actions) [![](https://github.com/CpanelInc/Overload-FileCheck/workflows/windows/badge.svg)](https://github.com/CpanelInc/Overload-FileCheck/actions)

With this module you can provide your own pure perl code when performing
file checks using one of the -X ops: -e, -f, -z, ...

[https://perldoc.perl.org/functions/-X.html](https://perldoc.perl.org/functions/-X.html)

```
  -r  File is readable by effective uid/gid.
  -w  File is writable by effective uid/gid.
  -x  File is executable by effective uid/gid.
  -o  File is owned by effective uid.
  -R  File is readable by real uid/gid.
  -W  File is writable by real uid/gid.
  -X  File is executable by real uid/gid.
  -O  File is owned by real uid.
  -e  File exists.
  -z  File has zero size (is empty).
  -s  File has nonzero size (returns size in bytes).
  -f  File is a plain file.
  -d  File is a directory.
  -l  File is a symbolic link (false if symlinks aren't
      supported by the file system).
  -p  File is a named pipe (FIFO), or Filehandle is a pipe.
  -S  File is a socket.
  -b  File is a block special file.
  -c  File is a character special file.
  -t  Filehandle is opened to a tty.
  -u  File has setuid bit set.
  -g  File has setgid bit set.
  -k  File has sticky bit set.
  -T  File is an ASCII or UTF-8 text file (heuristic guess).
  -B  File is a "binary" file (opposite of -T).
  -M  Script start time minus file modification time, in days.
  -A  Same for access time.
  -C  Same for inode change time (Unix, may differ for other
platforms)
```

Also view pp\_sys.c from the Perl source code, where are defined the original OPs.

In addition it's also possible to mock the Perl OP `stat` and `lstat`, read ["Mocking stat and lstat"](#mocking-stat-and-lstat) section for more details.

# Usage and Examples

When using this module, you can decide to mock filecheck OPs on import or later
at run time.

## Mocking filecheck at import time

You can mock multiple filecheck at import time.
Note that the ':check' will import constants like:
CHECK\_IS\_TRUE, CHECK\_IS\_FALSE, FALLBACK\_TO\_REAL\_OP
which are recommended return values to use in your hook functions.

```perl
#!perl

use strict;
use warnings;

use Overload::FileCheck '-e' => \&my_dash_e, -f => sub { 1 }, ':check';

# example of your own callback function to mock -e
# when returning
#  0: the test is false
#  1: the test is true
# -1: you want to use the answer from Perl itself :-)

sub dash_e {
    my ($file_or_handle) = @_;

    # return true on -e for this specific file
    return CHECK_IS_TRUE if $file_or_handle eq '/this/file/is/not/there/but/act/like/if/it/was';

    # claim that /tmp is not available even if it exists
    return CHECK_IS_FALSE if $file_or_handle eq '/tmp';

    # delegate the answer to the Perl CORE -e OP
    #   as we do not want to control these files
    return FALLBACK_TO_REAL_OP;
}
```

## Mocking filecheck at run time

You can also get a similar behavior by declaring the overload later at run time.

```perl
#!perl

use strict;
use warnings;

use Overload::FileCheck q(:all);

mock_file_check( '-e' => \&my_dash_e );
mock_file_check( '-f' => sub { CHECK_IS_TRUE } );

sub dash_e {
    my ($file_or_fh) = @_;

    # return true on -e for this specific file
    return CHECK_IS_TRUE if $file_or_fh eq '/this/file/is/not/there/but/act/like/if/it/was';

    # claim that /tmp is not available even if it exists
    return CHECK_IS_FALSE if $file_or_fh eq '/tmp';

    # delegate the answer to the Perl CORE -e OP
    #   as we do not want to control these files
    return FALLBACK_TO_REAL_OP;
}
```

## Check helpers to use in your callback function

In your callback function you should use the following helpers to return.

- **CHECK\_IS\_FALSE**: use this constant when the test is false
- **CHECK\_IS\_TRUE**: use this when you the test is true
- **FALLBACK\_TO\_REAL\_OP**: you want to delegate the answer to Perl itself :-)

It's also possible to return one integer. Checks like `-s`, `-M`, `-C`, `-A` can return
any integers.

Example:

```perl
use Overload::FileCheck q(:all);

mock_file_check( '-s' => \&my_dash_s );

sub my_dash_s {
    my ( $file_or_handle ) = @_;

    if ( $file_or_handle eq '/a/b/c' ) {
        return 42;
    }

    return FALLBACK_TO_REAL_OP;
}
```

## Tracing all file checks usage

You can trace all file checks in your codebase without altering it.

```perl
#!perl

use strict;
use warnings;

use Carp;
use Overload::FileCheck q{:all};

mock_all_file_checks( \&my_custom_check );

sub my_custom_check {
    my ( $check, $f ) = @_;

    local $Carp::CarpLevel = 2;    # do not display Overload::FileCheck stack
    printf( "# %-10s called from %s", "-$check '$f'", Carp::longmess() );

    # fallback to the original Perl OP
    return FALLBACK_TO_REAL_OP;
}

-d '/root';
-l '/root';
-e '/';
-d '/';

unmock_all_file_checks();

__END__

# The ouput looks similar to

-d '/root' called from  at t/perldoc_mock-all-file-check-trace.t line 26.
-l '/root' called from  at t/perldoc_mock-all-file-check-trace.t line 27.
-e '/'     called from  at t/perldoc_mock-all-file-check-trace.t line 28.
-d '/'     called from  at t/perldoc_mock-all-file-check-trace.t line 29.
```

## Mock one or more file checks: -e, -f

You can mock a single file check type like '-e', '-f', ...

```perl
#!perl

use strict;
use warnings;

use Overload::FileCheck qw{mock_file_check unmock_file_check unmock_all_file_checks :check};
use Errno ();

# all -f checks will be true from now
mock_file_check( '-f' => sub { 1 } );

# mock all calls to -e and delegate to the function dash_e
mock_file_check( '-e' => \&dash_e );

# example of your own callback function to mock -e
# when returning
#  0: the test is false
#  1: the test is true
# -1: you want to use the answer from Perl itself :-)

sub dash_e {
    my ($file_or_fh) = @_;

    # return true on -e for this specific file
    return CHECK_IS_TRUE
      if $file_or_fh eq '/this/file/is/not/there/but/act/like/if/it/was';

    # claim that /tmp is not available even if it exists
    if ( $file_or_fh eq '/tmp' ) {

        # you can set Errno to any custom value
        #   or it would be set to Errno::ENOENT() by default
        $! = Errno::ENOENT();    # set errno to "No such file or directory"
        return CHECK_IS_FALSE;
    }

    # delegate the answer to the Perl CORE -e OP
    #   as we do not want to control these files
    return FALLBACK_TO_REAL_OP;
}

# unmock -e and -f
unmock_file_check('-e');
unmock_file_check('-f');
unmock_file_check(qw{-e -f});

# or unmock all existing filecheck
unmock_all_file_checks();
```

## Mock check calls at import time

You can also mock the check functions at import time by providing a check test
and a custom function

```perl
#!perl

use strict;
use warnings;

use Test::More;
use Overload::FileCheck '-e' => \&my_dash_e, q{:check};

# Mock one or more check
#use Overload::FileCheck '-e' => \&my_dash_e, '-f' => sub { 1 }, 'x' => sub { 0 }, ':check';

my @exist     = qw{cherry banana apple};
my @not_there = qw{chocolate and peanuts};

sub my_dash_e {
    my $f = shift;

    note "mocked -e called for", $f;

    return CHECK_IS_TRUE  if grep { $_ eq $f } @exist;
    return CHECK_IS_FALSE if grep { $_ eq $f } @not_there;

    # we have no idea about these files
    return FALLBACK_TO_REAL_OP;
}

foreach my $f (@exist) {
    ok( -e $f, "file '$f' exists" );
}

foreach my $f (@not_there) {
    ok( !-e $f, "file '$f' exists" );
}

# this is using the fallback logic '-1'
ok -e $0,  q[$0 is there];
ok -e $^X, q[$^X is there];

done_testing;
```

# Mocking stat and lstat

## How to mock stat?

Here is a short sample how you can mock stat and lstat.
This is an extract from the testsuite, Test2::\* modules are
just there to illustrate the behavior. You should not necessary use them
in your code.

For more advanced samples, browse to the source code and check the test files
in t or examples directories.

```perl
#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck q(:all);

# our helper would be called for every stat & lstat calls
mock_stat( \&my_stat );

sub my_stat {
    my ( $opname, $file_or_handle ) = @_;

    # $opname can be 'stat' or 'lstat'
    # in this sample only mock stat, leave lstat alone
    return FALLBACK_TO_REAL_OP() if $opname eq 'lstat';

    my $f = $file_or_handle;    # alias for readability

    # return an array ref with 13 elements containing the stat output
    return [ 1 .. 13 ] if $f eq $0;

    my $fake_stat = [ (0) x 13 ];

    # you also have access to some constants
    # to set the stat values in the correct slot
    # this is using some fake values, without any specific meaning...
    $fake_stat->[ST_DEV]     = 1;
    $fake_stat->[ST_INO]     = 2;
    $fake_stat->[ST_MODE]    = 4;
    $fake_stat->[ST_NLINK]   = 8;
    $fake_stat->[ST_UID]     = 16;
    $fake_stat->[ST_GID]     = 32;
    $fake_stat->[ST_RDEV]    = 64;
    $fake_stat->[ST_SIZE]    = 128;
    $fake_stat->[ST_ATIME]   = 256;
    $fake_stat->[ST_MTIME]   = 512;
    $fake_stat->[ST_CTIME]   = 1024;
    $fake_stat->[ST_BLKSIZE] = 2048;
    $fake_stat->[ST_BLOCKS]  = 4096;

    return $fake_stat if $f eq 'fake.stat';

    # can also retun stats as a hash ref
    return { st_dev => 1, st_atime => 987654321 } if $f eq 'hash.stat';

    return {
        st_dev     => 1,
        st_ino     => 2,
        st_mode    => 3,
        st_nlink   => 4,
        st_uid     => 5,
        st_gid     => 6,
        st_rdev    => 7,
        st_size    => 8,
        st_atime   => 9,
        st_mtime   => 10,
        st_ctime   => 11,
        st_blksize => 12,
        st_blocks  => 13,
    } if $f eq 'hash.stat.full';

    # return an empty array if you want to mark the file as not available
    return [] if $f eq 'file.is.not.there';

    # fallback to the regular OP
    return FALLBACK_TO_REAL_OP();
}

is [ stat($0) ], [ 1 .. 13 ], 'stat is mocked for $0';
is [ stat(_) ], [ 1 .. 13 ],
  '_ also works: your mocked function is not called';

is [ stat('fake.stat') ],
  [ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 ], 'fake.stat';

is [ stat('hash.stat.full') ], [ 1 .. 13 ], 'hash.stat.full';

unmock_stat();

done_testing;
```

## Convenient constants available when mocking stat

When mocking stat or lstat function your callback function should return one of the following

- either one ARRAY Ref containing 13 entries as described by the stat function (in the same order)
- or an empty ARRAY Ref, if the file does not exist
- or one HASH ref using one or more of the following keys: st\_dev, st\_ino, st\_mode, st\_nlink,
  st\_uid, st\_gid, st\_rdev, st\_size, st\_atime, st\_mtime, st\_ctime, st\_blksize, st\_blocks
- or return FALLBACK\_TO\_REAL\_OP when you want to let Perl take back the control for that file

In order to manipulate the ARRAY ref and insert/update one specific entry, some constant are available
to access to the correct index via a 'name':

- ST\_DEV
- ST\_INO
- ST\_MODE
- ST\_NLINK
- ST\_UID
- ST\_GID
- ST\_RDEV
- ST\_SIZE
- ST\_ATIME
- ST\_MTIME
- ST\_CTIME
- ST\_BLKSIZE
- ST\_BLOCKS

## Mocking all file checks from a single 'stat' function

A recommended option is to only mock the 'stat' and 'lstat' function
and let Overload::FileCheck mock for you all file checks: -e, -f, -s, -z, ...

By doing so, using '\_' or '\*\_' (a.k.a. PL\_defgv) in your filecheck would work without any extra effort.

```perl
-d "/my/file" && -s _
```

Netherway some limitations exist. Indeed the checks '-B' and '-T' are using some heuristics to determine
if the file is a binary or a text. This would require more than just a simple stat output.
In these cases you can mock the -B and -T to your own functions.

```perl
mock_file_check( '-B' => sub { ... } );
mock_file_check( '-T' => sub { ... } );
```

### mock\_all\_from\_stat

By using 'mock\_all\_from\_stat' function, you will only provide a 'fake' stat / lstat function and
let Overload::FileCheck provide the hooks for all common checks

```perl
#!perl

use strict;
use warnings;

# setup at import time
use Overload::FileCheck '-from-stat' => \&mock_stat_from_sys, qw{:check :stat};

# or set it later at run time
# mock_all_from_stat( \&my_stat );

sub mock_stat_from_sys {

    my ( $stat_or_lstat, $f ) = @_;

    # $stat_or_lstat would be set to 'stat' or 'lstat' depending
    #   if it's a 'stat' or 'lstat' call

    if ( defined $f && $f eq 'mocked.file' ) {    # "<<$f is mocked>>"
        return [                                  # return a fake stat output (regular file)
            64769,      69887159,   33188, 1, 0, 0, 0, 13,
            1539928982, 1539716940, 1539716940,
            4096,       8
        ];

        return stat_as_file();

        return [];                                # if the file is missing
    }

    # let Perl answer the stat question for us
    return FALLBACK_TO_REAL_OP;
}

# ...

# later in your code
if ( -e 'mocked.file' && -f _ && !-d _ ) {
    print "# This file looks real...\n";
}

# ...

# you can unmock the OPs at anytime
Overload::FileCheck::unmock_all_file_checks();
```

## Using stat\_as\_\* helpers

When mocking the stat functions you might consider using one of the 'stat\_as\_\*' helper.
Available functions are:

- stat\_as\_directory
- stat\_as\_file
- stat\_as\_symlink
- stat\_as\_socket
- stat\_as\_chr
- stat\_as\_block

All of these functions take some optional arguments to set: uid, gid, size, atime, mtime, ctime, perms, size.
Example:

```perl
use Overload::FileCheck -from-stat => \&my_stat, q{:check};

sub my_stat {
    my ( $stat_or_lstat, $f_or_fh ) = @_;

    return stat_as_file() if $f_or_fh eq 'fake.file';

    return stat_as_directory( uid => 0, gid => 'root' ) if $f_or_fh eq 'fake.dir';

    return stat_as_file( mtime => time() ) if $f_or_fh eq 'touch.file';

    return stat_as_file( perms => 0755 ) if $f_or_fh eq 'touch.file.0755';

    return FALLBACK_TO_REAL_OP;
}
```

# Available functions

## mock\_file\_check( $check, CODE )

mock\_file\_check function is used to mock one of the filecheck op.

The first argument is one of the file check: '-f', '-e', ... where the dash is optional.
It also accepts 'e', 'f', ...

When trying to mock a filecheck already mocked, the function will die with an error like

```
-f is already mocked by Overload::FileCheck
```

This would guarantee that you are not mocking multiple times the same filecheck in your codebase.

Otherwise returns 1 on success.

```perl
# this is probably a very bad idea to do this in your codebase
# but can be useful for some testing
# in that sample all '-e' checks will always return true...
mock_file_check( '-e' => sub { 1 } )
```

## unmock\_file\_check( $check, \[@extra\_checks\] )

Disable the effect of one or more specific mock.
The argument to unmock\_file\_check can be a list or a single scalar value.
The leading dash is optional.

```
unmock_file_check( '-e' );
unmock_file_check( 'e' );            # also work without the dash
unmock_file_check( qw{-e -f -z} );
unmock_file_check( qw{e f} );        # also work without the dashes
```

## unmock\_all\_file\_checks()

By a simple call to unmock\_all\_file\_checks, you would disable the effect of overriding the
filecheck OPs. (not that the XS code is still plugged in, but fallback as soon
as possible to the original OP)

## mock\_stat( CODE )

mock\_stat provides one interface to setup a hook for all `stat` and `lstat` calls.
It's slighly different than the other mock functions. As the first argument passed to
the hook function would be a string 'stat' or 'lstat'.

You can get a more advanced hook sample from ["Mocking stat"](#mocking-stat).

```perl
use Overload::FileCheck q(:all);

# our helper would be called for every stat & lstat calls
mock_stat( \&my_stat );

sub my_stat {
    my ( $opname, $file_or_handle ) = @_;

    ...

    return FALLBACK_TO_REAL_OP;
}
```

## unmock\_stat()

By calling unmock\_stat, you would disable any previous hook set using mock\_stat

## mock\_all\_from\_stat( CODE )

By providing a single hook for 'stat' and 'lstat' you let OverLoad::FileCheck take care
of mocking all other -X checks.

read [" Mocking all file checks from a single 'stat' function"](#mocking-all-file-checks-from-a-single-stat-function) for sample usage.

## stat\_as\_directory( %OPTS )

Create a stat array ref for a directory.
%OPTS is optional and can set one or more using arguments among: uid, gid, size, atime, mtime, ctime, perms, size.
read the section ["Using stat\_as\_\* helpers"](#using-stat_as_-helpers) for some sample usages.

## stat\_as\_file( %OPTS )

Create a stat array ref for a regular file
view stat\_as\_directory and ["Using stat\_as\_\* helpers"](#using-stat_as_-helpers) for some sample usages

## stat\_as\_symlink( %OPTS )

Create a stat array ref for a symlink
view stat\_as\_directory and ["Using stat\_as\_\* helpers"](#using-stat_as_-helpers) for some sample usages

## stat\_as\_socket( %OPTS )

Create a stat array ref for a socket
view stat\_as\_directory and ["Using stat\_as\_\* helpers"](#using-stat_as_-helpers) for some sample usages

## stat\_as\_chr( %OPTS )

Create a stat array ref for an empty character device
view stat\_as\_directory and ["Using stat\_as\_\* helpers"](#using-stat_as_-helpers) for some sample usages

## stat\_as\_block( %OPTS )

Create a stat array ref for an empty block device
view stat\_as\_directory and ["Using stat\_as\_\* helpers"](#using-stat_as_-helpers) for some sample usages

# Notice

This is a very early development stage and some behavior might change before the release of a more stable build.

# Known Limitations

## This is design for Unit Test purpose

This code was mainly designed to be used during unit tests. It's far from being optimized at this time.

## Mock as soon as possible

Code loaded/interpreted before mocking a file check, would not take benefit of Overload::FileCheck.
You probably want to load and call the mock function of Overload::FileCheck as early as possible.

## Empty string instead of Undef

Several test operators once mocked will not return the expected 'undef' value but one empty string
instead. This is a future improvement. If you check the output of -X operators in boolean context
it should not impact you.

## -B and -T are using heuristics

File check operators like -B and -T are using heuristics to guess if the file content is binary or text.
By using mock\_all\_from\_stat or ('-from-stat' at import time), we cannot provide an accurate -B or -T checks.
You would need to provide a custom hooks for them

# TODO

- support for 'undef' using CHECK\_IS\_UNDEF as valid return (in addition to CHECK\_IS\_FALSE)

# LICENSE

This software is copyright (c) 2018 by cPanel, Inc.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming
language system itself.

# DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY
APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE
SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE
OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY
WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS
BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

# AUTHOR

Nicolas R <atoomic@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by cPanel, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
