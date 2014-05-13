#!/usr/local/bin/perl -w

#	cleanup.pl
#
#	usage: perl cleanup.pl < nameoffile.txt
#
#	output goes to output.txt
#
# Removes repeats from lists
# Also makes sure everything is lowercase
#

my %words = ( );

while ( defined ($line = <STDIN>) ) {
    chomp $line;
	$words{ $line } = 1;

}

open OUTPUT, '>', "output.txt";

foreach my $val ( keys %words ) {

	print OUTPUT lc($val)."\n";

}

close OUTPUT;
