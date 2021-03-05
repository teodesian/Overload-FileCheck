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

use Overload::FileCheck q(:all);

my @chex_mix = qw{B b c d e f g k l O o p R r S T t u W w X x z};
our @mocked_as_true  = qw{peace life love /bin/i-am-there /usr/local/a/b/c/d/e};
our @mocked_as_false = qw{war drug /not/there /usr/lib /usr/lib64};

foreach my $FILE_CHECK (@chex_mix) {
    subtest "$FILE_CHECK" => sub {
        note "Testing -$FILE_CHECK";

        my ( @known_as_true, @known_as_false );

        # list of candidates where we would use the umock file check
        #	to know which state it is, and this should be preserved after the mock
        my @candidates = ( $^X, qw{/bin/true /bin/false / /home /root / /usr/local} );

        foreach my $f (@candidates) {
            if ( do_dash_check($f, $FILE_CHECK) ) {
                push @known_as_true, $f;
            }
            else {
                push @known_as_false, $f;
            }
        }
        # we are now mocking the function
        ok mock_file_check( $FILE_CHECK, \&my_dash_check ), "mocking -$FILE_CHECK";

        sub my_dash_check {
            my $f = shift;

            note "mocked check executed for file: ", $f;

            return CHECK_IS_TRUE  if grep { $_ eq $f } @mocked_as_true;
            return CHECK_IS_FALSE if grep { $_ eq $f } @mocked_as_false;

            # we have no idea about these files
            return FALLBACK_TO_REAL_OP;
        }

        foreach my $f ( @mocked_as_true, @known_as_true ) {
            ok( do_dash_check($f, $FILE_CHECK), "-$FILE_CHECK '$f' is true" );
        }

        foreach my $f ( @mocked_as_false, @known_as_false ) {
            ok( !do_dash_check($f, $FILE_CHECK), "-$FILE_CHECK '$f' is false" );
        }

        ok unmock_file_check($FILE_CHECK);
    };
}
done_testing;
exit;

sub do_dash_check {
    my ($what,$FILE_CHECK) = @_;
    # Don't do a stringy eval, as this is not portable with win32 pathnames
    my $c = "-$FILE_CHECK";
    return scalar eval { $c->($what) };
}
