#!/usr/bin/perl
# ----------------------------------------------------------------------------
#
# bayes.pl --- Classify a mail message manually
#
# Copyright (c) 2001-2011 John Graham-Cumming
#
#   This file is part of POPFile
#
#   POPFile is free software; you can redistribute it and/or modify it
#   under the terms of version 2 of the GNU General Public License as
#   published by the Free Software Foundation.
#
#   POPFile is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with POPFile; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
# ----------------------------------------------------------------------------

use strict;
use lib defined($ENV{POPFILE_ROOT})?$ENV{POPFILE_ROOT}:'./';
use POPFile::Loader;

my $code = 0;

if ( $#ARGV >= 0 ) {

    # POPFile is actually loaded by the POPFile::Loader object which does all
    # the work

    my $POPFile = POPFile::Loader->new();

    # Indicate that we should create not output on STDOUT (the POPFile
    # load sequence)

    $POPFile->debug(0);
    $POPFile->CORE_loader_init();
    $POPFile->CORE_signals();
    $POPFile->CORE_load( 1 );
    $POPFile->CORE_link_components();
    $POPFile->CORE_initialize();

    my @files;

    if ($^O =~ /linux/) {
        @files = @ARGV[0 .. $#ARGV];
    } else {
        @files = map { glob } @ARGV[0 .. $#ARGV];
    }

    @ARGV = ();

    if ( $POPFile->CORE_config() ) {

        # Prevent the tool from finding another copy of POPFile running

        my $c = $POPFile->get_module('POPFile::Config');
        my $current_piddir = $c->config_( 'piddir' );
        $c->config_( 'piddir', $c->config_( 'piddir' ) . 'bayes.pl.' );

        $POPFile->CORE_start();

        my $b = $POPFile->get_module('Classifier::Bayes');
        my $session = $b->get_session_key( 'admin', '' );

        foreach my $file (@files) {
            if ( !(-e $file) ) {
                print STDERR "Error: File `$file' does not exist, classification aborted.\n";
                $code = 1;
                last;
            }
        }

        if ( $code == 0 ) {
            foreach my $file (@files) {
                print "`$file' is `" . $b->classify( $session, $file ) . "'\n";
            }

            foreach my $word (sort keys %{$b->{parser__}->{words__}}) {
                print "$word $b->{parser__}->{words__}{$word}\n";
            }
        }

        $c->config_( 'piddir', $current_piddir );

        # Reload configuration file ( to avoid updating configurations )

        $c->load_configuration();

        $b->release_session_key( $session );
        $POPFile->CORE_stop();
    }
}
else
{
    print "bayes.pl - output the classification of a message\n\n";
    print "Usage: bayes.pl <messages>\n";
    print "       <messages>         Filename of message(s) to classify\n";
    $code = 1;
}

exit $code;
