# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use GD::Graph;
$loaded = 1;
print <<EOF;

There are no tests for GDGraph3d, yet. Neither Martien nor I have figured 
out a good way to provide accurate testing of the graph with all the 
different versions of GD out there. Perhaps I'll add some samples that you 
can "visually" verify in the future.
EOF

print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

