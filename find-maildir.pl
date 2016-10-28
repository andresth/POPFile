#!/usr/bin/perl
# ----------------------------------------------------------------------------
#
#
# ----------------------------------------------------------------------------

use strict;
use local::lib;

my $code = 0;

if ($#ARGV + 1 == 2) {
  my $searchDir = shift @ARGV;
  my $bucket = shift @ARGV;
  
  $bucket =~ s/_/[_ ]/g;

  opendir(DIR, $searchDir) or die $!;

  while (my $dir = readdir(DIR)) {
    next unless (-d "$searchDir/$dir");
    if ($dir =~ m/^\.$bucket$/i) {
      print "$searchDir/$dir", "\n";
      exit($code);
    }
  }

  $code = 0;
} else {
  $code = 0;
}

exit( $code );
