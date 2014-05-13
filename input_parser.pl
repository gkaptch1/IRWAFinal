#!/usr/local/bin/perl -w

#	input_parser.pl
#
#	extracts links from Chrome Bookmarks file

my @urls = ( );

while ( defined ($line = <STDIN>) ) {
    chomp $line;

    $returned = &get_urls ( $line );
    if ( $returned ne "") {
		push @urls, $returned;
	}

}

open OUTPUT, '>', "output.txt";

foreach my $val ( @urls ) {

	print OUTPUT lc($val)."\n";

}

close OUTPUT;


sub get_urls {

    my $content = shift;
    my %urls    = ();    # NOTE: this is an associative array so that we only
                         #       push the same "href" value once.

    if ( $content =~ /HREF/) {
    	my @parts = split (/\"/, $content);
    	foreach my $part ( @parts ){
    		if ( $part =~ /http/ ) { 
    			my @subparts = split ('#', $part);
    			return $subparts[0]; 
    		}
    	}
    }

    return "";
    
}

