#line 1
package Test::Pod::_parser;
use base 'Pod::Simple';
use strict;

sub _handle_element_start {
    my($parser, $element_name, $attr_hash_r) = @_;

    # Curiously, Pod::Simple supports L<text|scheme:...> rather well.

    if( $element_name eq "L" and $attr_hash_r->{type} eq "url") {
        $parser->{_state_of_concern}{'Lurl'} = $attr_hash_r->{to};
    }

    return $parser->SUPER::_handle_element_start(@_);
}

sub _handle_element_end {
    my($parser, $element_name) = @_;

    delete $parser->{_state_of_concern}{'Lurl'}
        if $element_name eq "L" and exists $parser->{_state_of_concern}{'Lurl'};

    return $parser->SUPER::_handle_element_end(@_);
}

sub _handle_text {
    my($parser, $text) = @_;
    if( my $href = $parser->{_state_of_concern}{'Lurl'} ) {
        if( $href ne $text ) {
            my $line = $parser->line_count() -2; # XXX: -2, WHY WHY WHY??

            $parser->whine($line, "L<text|scheme:...> is invalid according to perlpod");
        }
    }

    return $parser->SUPER::_handle_text(@_);
}

1;

package Test::Pod;

use strict;

#line 53

our $VERSION = '1.40';

#line 102

use 5.008;

use Test::Builder;
use File::Spec;

our %ignore_dirs = (
    '.bzr' => 'Bazaar',
    '.git' => 'Git',
    '.hg'  => 'Mercurial',
    '.pc'  => 'quilt',
    '.svn' => 'Subversion',
    CVS    => 'CVS',
    RCS    => 'RCS',
    SCCS   => 'SCCS',
    _darcs => 'darcs',
    _sgbak => 'Vault/Fortress',
);

my $Test = Test::Builder->new;

sub import {
    my $self = shift;
    my $caller = caller;

    for my $func ( qw( pod_file_ok all_pod_files all_pod_files_ok ) ) {
        no strict 'refs';
        *{$caller."::".$func} = \&$func;
    }

    $Test->exported_to($caller);
    $Test->plan(@_);
}

sub _additional_test_pod_specific_checks {
    my ($ok, $errata, $file) = @_;

    return $ok;
}

#line 157

sub pod_file_ok {
    my $file = shift;
    my $name = @_ ? shift : "POD test for $file";

    if ( !-f $file ) {
        $Test->ok( 0, $name );
        $Test->diag( "$file does not exist" );
        return;
    }

    my $checker = Test::Pod::_parser->new;

    $checker->output_string( \my $trash ); # Ignore any output
    $checker->parse_file( $file );

    my $ok = !$checker->any_errata_seen;
       $ok = _additional_test_pod_specific_checks( $ok, ($checker->{errata}||={}), $file );

    $Test->ok( $ok, $name );
    if ( !$ok ) {
        my $lines = $checker->{errata};
        for my $line ( sort { $a<=>$b } keys %$lines ) {
            my $errors = $lines->{$line};
            $Test->diag( "$file ($line): $_" ) for @$errors;
        }
    }

    return $ok;
} # pod_file_ok

#line 210

sub all_pod_files_ok {
    my @files = @_ ? @_ : all_pod_files();

    $Test->plan( tests => scalar @files );

    my $ok = 1;
    foreach my $file ( @files ) {
        pod_file_ok( $file, $file ) or undef $ok;
    }
    return $ok;
}

#line 245

sub all_pod_files {
    my @queue = @_ ? @_ : _starting_points();
    my @pod = ();

    while ( @queue ) {
        my $file = shift @queue;
        if ( -d $file ) {
            local *DH;
            opendir DH, $file or next;
            my @newfiles = readdir DH;
            closedir DH;

            @newfiles = File::Spec->no_upwards( @newfiles );
            @newfiles = grep { not exists $ignore_dirs{ $_ } } @newfiles;

            foreach my $newfile (@newfiles) {
                my $filename = File::Spec->catfile( $file, $newfile );
                if ( -f $filename ) {
                    push @queue, $filename;
                }
                else {
                    push @queue, File::Spec->catdir( $file, $newfile );
                }
            }
        }
        if ( -f $file ) {
            push @pod, $file if _is_perl( $file );
        }
    } # while
    return @pod;
}

sub _starting_points {
    return 'blib' if -e 'blib';
    return 'lib';
}

sub _is_perl {
    my $file = shift;

    return 1 if $file =~ /\.PL$/;
    return 1 if $file =~ /\.p(?:l|m|od)$/;
    return 1 if $file =~ /\.t$/;

    open my $fh, '<', $file or return;
    my $first = <$fh>;
    close $fh;

    return 1 if defined $first && ($first =~ /^#!.*perl/);

    return;
}

#line 330

1;
