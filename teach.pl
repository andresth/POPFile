#!/usr/bin/perl
# ----------------------------------------------------------------------------
#
#
# ----------------------------------------------------------------------------

use strict;
use local::lib;
use lib defined($ENV{POPFILE_ROOT})?$ENV{POPFILE_ROOT}:'./';
use POPFile::Loader;

sub teach_on_error {
    my $teachDir = shift;
    my $teachBucket = shift;
    my $classifier = $main::b;
    
    my $counter = 0;
    # Get session key from classifier.
    my $session = $main::session;
    
    # Does the bucket exist? If not, create one.
    if (!$classifier->is_bucket($session, $teachBucket)) {
        $classifier->create_bucket($session, $teachBucket);
    }
    
    opendir(teachDir, $teachDir);
    
    while (my $file = readdir(teachDir)) {
        next unless (!(-d "$teachDir/$file"));
        
        print "Checking file: $file\n" if ($main::verbose);
        if (has_relevant_links("$teachDir/$file")) {
            print "Message is linked in multiple folders. Skipping!\n" if ($main::verbose);
            next;
        }
        
        # Find current classification
        open(mailFile, "<", "$teachDir/$file");
        my $mailBucket;
        my @mailLines = <mailFile>;
        foreach (@mailLines) {
            if ($_ =~ m/^X-Text-Classification: (.*)/im) {
                $mailBucket = $1;
                last;
            }
        }
        close(mailFile);
        
        # Do not train unclassified mails in inbox
        next if ($teachBucket eq "inbox" && $mailBucket eq "unclassified");
        
        # Decide what to do
        if ($mailBucket ne "" && $mailBucket ne $teachBucket) {
            print "Message needs to be taught!\nClassified as `$mailBucket` but sould be `$teachBucket`.\n" if ($main::verbose);
            $classifier->add_message_to_bucket($session, $teachBucket, "$teachDir/$file");
            $classifier->remove_message_from_bucket($session, $mailBucket, "$teachDir/$file") if ($mailBucket ne "unclassified");

            $counter++;

            my @newMailLines;
            foreach (@mailLines) {
                if ($_ =~ m/^X-Text-Classification: (.*)/im) {
                    push(@newMailLines, "X-Text-Classification: $teachBucket\n");
                } else {
                    push(@newMailLines, $_);
                }
            }
            open(mailFile, ">", "$teachDir/$file");
            print mailFile @newMailLines;
            close(mailFile);

        } else {
            print "Message seems fine.\n" if ($main::verbose);
        }
    }
    
    closedir(teachDir);
    
    return $counter;
}

sub has_relevant_links {
    my $lnFile = shift;
    my $counter = 0;
    
    (my $matchWords = join("|", @main::ignoreDirs)) =~ s/\./\\\./g;
    foreach my $cmdline (`/bin/find "$main::searchDir" -samefile "$lnFile"`) {
        $counter++ if ($cmdline !~ m/($matchWords)/i);
    }
    
    return $counter - 1;
}

my $code = 0;
our @ignoreDirs = (".Drafts", ".Trash", ".Archive", ".Sent", ".Spam");
my $count = 0;
our $verbose = 0;

if ($#ARGV + 1 == 1) {
    # POPFile is actually loaded by the POPFile::Loader object which does all the work
    my $POPFile = POPFile::Loader->new();

    # Indicate that we should create not output on STDOUT (the POPFile load sequence)
    $POPFile->debug(0);
    $POPFile->CORE_loader_init();
    $POPFile->CORE_signals();
    $POPFile->CORE_load(1);
    $POPFile->CORE_link_components();
    $POPFile->CORE_initialize();

    our $searchDir = shift @ARGV;
    
    unless (-d "$searchDir") {
      print STDERR "Directory `$searchDir` does not exist.\n";
      exit(1);
    }

    if ( $POPFile->CORE_config() ) {
        # Prevent the tool from finding another copy of POPFile running
        my $c = $POPFile->get_module( 'POPFile::Config' );
        my $current_piddir = $c->config_( 'piddir' );
        $c->config_( 'piddir', $c->config_( 'piddir' ) . 'insert.pl.' );

        $POPFile->CORE_start();

        our $b = $POPFile->get_module( 'Classifier::Bayes' );
        our $session = $b->get_session_key( 'admin', '' );

        opendir(mainDir, $searchDir) or die $!;

        while (my $dir = readdir(mainDir)) {
            next unless (-d "$searchDir/$dir");
            next unless (!($dir ~~ (".", "..")));
            next unless (!($dir ~~ @ignoreDirs));
            next unless ($dir =~ m/^\.(?:[^\d]{1}[^.]+)$/im);
            print "$searchDir/$dir", "\n" if ($main::verbose);
            (my $bucket = lc $dir) =~ s/\.//g;
            $bucket =~ s/ /_/g;
            print $bucket, "\n" if ($main::verbose);
            
            $count += teach_on_error("$searchDir/$dir/cur", $bucket);

            print "\n" if ($main::verbose);
        }
        closedir(mainDir);
        
        # Also teach inbox
        print "$searchDir\ninbox\n" if ($main::verbose);
        $count += teach_on_error("$searchDir/cur", "inbox");
        
        print "$count mails have been trained.\n" if ($count);

        # Remove unuses buckets
        my @buckets = $b->get_buckets($session);
	foreach (@buckets) {
		next if ($_ eq "inbox");
		my $foundDir = 0;
		(my $bucketEx = $_) =~ s/_/[_ ]/g;
		opendir(mainDir, $searchDir);
		
		while (my $dir = readdir(mainDir)) {
			next unless (-d "$searchDir/$dir");
			if ($dir =~ m/^\.$bucketEx$/i) {
				$foundDir = 1;
				last;
			}
		}
		closedir(mainDir);
		
		# Remove bucket
		unless ($foundDir) {
			$b->delete_bucket($session, $_);
			print "Deleted bucket `$_`because folder does not exist.\n";
		}
	}
        
        
        $c->config_( 'piddir', $current_piddir );

        # Reload configuration file ( to avoid updating configurations )
        $c->load_configuration();

        $b->release_session_key( $session );
        $POPFile->CORE_stop();
    }    
} else {
	$code = 1;
}

exit( $code );

