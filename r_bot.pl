#!/usr/local/bin/perl -w

# r_bot.pl
#
#
#   Task 1: Extract the Documents in the input html files
#   Task 2: Build Document Vectors
#   Task 3: Find More Stuff



use Carp;
use HTML::LinkExtor;
use HTML::PullParser;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status;
use LWP::RobotUA;
use URI::URL;

#GLOBAL VARS
%foodwords = ();
%foodverbs = ();


URI::URL::strict( 1 ); 

my $log_file = shift (@ARGV);
my $input_file = shift (@ARGV);
if ((!defined ($log_file)) || (!defined ($input_file))) {
    print STDERR "You must specify a log file, a content file and a base_url\n";
    print STDERR "when running the web robot:\n";
    print STDERR "  ./robot_base.pl mylogfile.log content.txt base_url\n";
    exit (1);
}

$| = 1;

open LOG, '>', "$log_file";
open CONTENT, '>', "$input_file";


my $ROBOT_NAME = 'KaptchukChandlerFoodBot/1.0';
my $ROBOT_MAIL = 'gkaptch1@jhu.edu';

my $robot = new LWP::RobotUA $ROBOT_NAME, $ROBOT_MAIL;
$robot->delay( .01 );

my $base_url    = shift(@ARGV);   

&initialize_vectors();
&setup_data($input_file);

my @search_urls = ();    # current URL's waiting to be trapsed
my @wanted_urls = ();    # URL's which contain info that we are looking for
my %relevance   = ();    # how relevant is a particular URL to our search
my %pushed      = ();    # URL's which have either been visited or are already
                         #  on the @search_urls array
    
push @search_urls, $base_url;
$pushed{ $base_url } = 1;
print $base_url . "\n";

print LOG "ALIVE\n";
################################################
#
#                    BEGIN
#
################################################
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

    print LOG "[HEAD ] $url\n";

    my $request  = new HTTP::Request HEAD => $url;
    my $response = $robot->request( $request );

    if ($response->code != RC_OK) { return 0; }
    #if (! &wanted_content( $response->content_type ) ) { return 0; }

    print LOG "[GET  ] $url\n";

    $request->method( 'GET' );
    $response = $robot->request( $request );

    if ($response->code != RC_OK) { return 0; }
    if ($response->content_type !~ m@text/html@) { return 0; }

    print LOG "[LINKS] $url\n";


    my $content =  $response->content;


    &extract_content ($content, $url);

    my @related_urls  = &grab_urls( $content );

    foreach my $link (@related_urls) {

      #  my $full_url = eval { (new URI::URL $link, $response->base)->abs; };
      my $full_url = $link;
        if ($full_url =~ '#') {
            my @temp = split ('#', $full_url);
            $full_url = $temp[0];
        }
            
        delete $relevance{ $link } and next if $@;

        $relevance{ $full_url } = $relevance{ $link };
        delete $relevance{ $link } if $full_url ne $link;

        chomp $full_url;

        if ( (!exists $pushed{ $full_url }) && $full_url =~ $base_url) {
            push @search_urls, $full_url;
            $pushed{ $full_url } = 1;
        }
        
    }

    #
    # reorder the urls base upon relevance so that we search
    # areas which seem most relevant to us first.
    #

    @search_urls = 
    sort { $relevance{ $a } <=> $relevance{ $b }; } @search_urls;

}

close LOG;
close CONTENT;

exit (0);

##############################
# INITIALIZE_VECTORS
#
# Reads in the words files and sets
# up the approprite vectors
##############################

sub initialize_vectors {

    $foods_file = "./foodwords.txt";
    $verbs_file = "./verbs.txt";

    open(FOODS_FILE,$foods_file) || die "Can't open $foods_file: $!\n";
 
    while( defined ($line = <FOODS_FILE>) ) {
        chomp $line;
        $foodwords{$line}    = 1;
    }

    close FOODS_FILE;

    open(VERBS_FILE,$verbs_file) || die "Can't open $verbs_file: $!\n";
 
    while( defined ($line = <VERBS_FILE>) ) {
        chomp $line;
        $foodverbs{$line}    = 1;
    }

    close VERBS_FILE;

}

######################################
# SETUP_DATA
#
# Reads in the links from the input file
#
# We access each of the web pages in turn and 
# extract all of the plaintext to create our corpus
# and initialize our ingredient user profile
#
########################################

sub setup_data {

    $input_filename = shift;

    open(INPUT_FILE,$input_filename) || die "Can't open $input_filename: $!\n";

    while( defined ( $url = <INPUT_FILE>) ) {

        # We access each of the links one at a time...
        chomp $url;

        my $page_html = &retreive_webpage($url);
        
        if ( $page_html == 0 ) {
            print LOG "Could Not Retreive The HTML for $url\n";
            next;
        }



    }

}


######################################
# RETREIVE_WEBPAGE
#
# Handles extraction of the webpage
# Execution of HTTP requests
#
########################################

sub retreive_webpage {


   my $url = shift @search_urls;
    print "\n" . $url . ":\n";

    #
    # insure that the URL is well-formed, otherwise skip it
    # if not or something other than HTTP
    #

    my $parsed_url = eval { new URI::URL $url; };

    next if $@;
    next if $parsed_url->scheme !~/http/i;

    print LOG "[HEAD ] $url\n";

    my $request  = new HTTP::Request HEAD => $url;
    my $response = $robot->request( $request );

    if ($response->code != RC_OK) { return 0; }
    #if (! &wanted_content( $response->content_type ) ) { return 0; }

    print LOG "[GET  ] $url\n";

    $request->method( 'GET' );
    $response = $robot->request( $request );

    if ($response->code != RC_OK) { return 0; }
    if ($response->content_type !~ m@text/html@) { return 0; }

    print LOG "[LINKS] $url\n";


    return $response->content;

}


######################################
# EXTRACT_CONTENT
#
# Handles extraction of the webpage
# Execution of HTTP requests
#
########################################
sub extract_content {
    my $content = shift;
    my $url = shift;

    my $email;
    my $phone;

    # parse out information you want
    # print it in the tuple format to the CONTENT and LOG files, for example:

#    print CONTENT "($url; EMAIL; $email)\n";
#    print LOG "($url; EMAIL; $email)\n";

#    print CONTENT "($url; PHONE; $phone)\n";
#    print LOG "($url; PHONE; $phone)\n";

    
    $content =~ s/&nbsp;/ /g;
    my @lines = split(/[>][\s]*[<]/, $content);
   # foreach my $val (@lines) {
    #}
    print "LIKE NIGGA WE MADE IT\n";

}

######################################
# GRAB_URLS
#
# Grabs any relavent urls found on the page
#
########################################

sub grab_urls {
    my $content = shift;
    my %urls    = ();    # NOTE: this is an associative array so that we only
                         #       push the same "href" value once.

    
  #skip:
    while ($content =~ s/<\s*[aA] ([^>]*)>\s*(?:<[^>]*>)*(?:([^<]*)(?:<[^aA>]*>)*<\/\s*[aA]\s*>)?//) {
        
        my $tag_text = $1;
        my $reg_text = $2;
        my $link = "";

        if (defined $reg_text) {
            $reg_text =~ s/[\n\r]/ /;
            $reg_text =~ s/\s{2,}/ /;

            my @words = split (/\s/, $reg_text);

            my $matches = 0;

            foreach my $wrd (@words) {
                if ($tag_text=~ m/\Q$wrd/i) {
                    $matches ++;
                }
            }
            $relevance { $link } = $matches;
            $urls { $link }      = 1;
        } elsif ($tag_text =~ /href\s*=\s*(?:["']([^"']*)["']|([^\s])*)/i) {
            $link = $1 || $2;

            $relevance{ $link } = 1;
            $urls{ $link }      = 1;
        }
    }

    return keys %urls;   # the keys of the associative array hold all the
                         # links we've found (no repeats).
}


