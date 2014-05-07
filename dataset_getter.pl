#!/usr/local/bin/perl -w

#
# This program walks through HTML pages, extracting all the links to other
# text/html pages and then walking those links. Basically the robot performs
# a breadth first search through an HTML directory structure.
#
# All other functionality must be implemented
#
# Example:
#
#    robot_base.pl content.txt http://www.cs.jhu.edu/
#
# Note: you must use a command line argument of http://some.web.address
#       or else the program will fail with error code 404 (document not
#       found).

#use strict;

use Carp;
use HTML::LinkExtor;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status;
use LWP::RobotUA;
use URI::URL;

URI::URL::strict( 1 );   # insure that we only traverse well formed URL's


my $content_file = shift (@ARGV);
if ((!defined ($content_file))) {
    print STDERR "You must specify a log file, a content file and a base_url\n";
    print STDERR "when running the web robot:\n";
    print STDERR "  ./robot_base.pl mylogfile.log content.txt base_url\n";
    exit (1);
}

$| = 1;

open CONTENT, '>>', "$content_file";


my $ROBOT_NAME = 'DataSetCollector/1.0';
my $ROBOT_MAIL = 'gkaptch1@jhu.edu';

#
# create an instance of LWP::RobotUA. 
#
# Note: you _must_ include a name and email address during construction 
#       (web site administrators often times want to know who to bitch at 
#       for intrusive bugs).
#
# Note: the LWP::RobotUA delays a set amount of time before contacting a
#       server again. The robot will first contact the base server (www.
#       servername.tag) to retrieve the robots.txt file which tells the
#       robot where it can and can't go. It will then delay. The default 
#       delay is 1 minute (which is what I am using). You can change this 
#       with a call of
#
#         $robot->delay( $ROBOT_DELAY_IN_MINUTES );
#
#       At any rate, if your program seems to be doing nothing, wait for
#       at least 60 seconds (default delay) before concluding that some-
#       thing is wrong.
#

my $robot = new LWP::RobotUA $ROBOT_NAME, $ROBOT_MAIL;
$robot->delay( .01 );

my $base_url    = shift(@ARGV);   # the root URL we will start from

my @search_urls = ();    # current URL's waiting to be trapsed
my @wanted_urls = ();    # URL's which contain info that we are looking for
my %relevance   = ();    # how relevant is a particular URL to our search
my %pushed      = ();    # URL's which have either been visited or are already
                         #  on the @search_urls array
    
push @search_urls, $base_url;
$pushed{ $base_url } = 1;
#print $base_url . "\n";

print "ALIVE\n";

while (@search_urls) {
    my $url = shift @search_urls;
    print "\n" . $url . ":\n";

    #
    # insure that the URL is well-formed, otherwise skip it
    # if not or something other than HTTP
    #

    my $parsed_url = eval { new URI::URL $url; };

    next if $@;
    next if $parsed_url->scheme !~/http/i;
	
    #
    # get header information on URL to see it's status (exis-
    # tant, accessible, etc.) and content type. If the status
    # is not okay or the content type is not what we are 
    # looking for skip the URL and move on
    # 

    my $request  = new HTTP::Request HEAD => $url;
    my $response = $robot->request( $request );
	
    next if $response->code != RC_OK;

    $request->method( 'GET' );
    $response = $robot->request( $request );

    next if $response->code != RC_OK;
    next if $response->content_type !~ m@text/html@;
    
    &extract_content ($response->content, $url);

}

close CONTENT;

exit (0);
    

#
# extract_content
#
#  this function should read through the context of all the text/html
#  documents retrieved by the web robot and extract three types of
#  contact information described in the assignment

sub extract_content {
    my $content = shift;
    my $url = shift;

    #just in case
    $content =~ s/&nbsp;/ /g;


    my @lines = split(/[>][\s]*[<]/, $content);
    foreach my $val (@lines) {
        
        next if $val !~ /^li>/;

        my @peices = split(/[<>]/, $val);

        foreach my $peice (@peices) {

            if (length ($peice) > 3 && length ($peice) < 15 ) {
                print CONTENT "$peice\n";
            }

        }

    }
    return;
}
