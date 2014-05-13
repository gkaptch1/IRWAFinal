#!/usr/local/bin/perl -w

# recipe_bot.pl
#
#
#   Task 1: Extract the Documents in the input html files
#   Task 2: Build Document Vectors
#   Task 3: Find More Stuff



use Carp;
use HTML::LinkExtor;
use HTML::TokeParser;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status;
use LWP::RobotUA;
use URI::URL;

#GLOBAL VARS
%foodwords = ();
%foodverbs = ();
%user_profile = ();

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

my $ROBOT_NAME = 'KaptchukChandlerFoodBot/1.0';
my $ROBOT_MAIL = 'gkaptch1@jhu.edu';

my $robot = new LWP::RobotUA $ROBOT_NAME, $ROBOT_MAIL;
$robot->delay( .05 );

my $base_url    = shift(@ARGV);   

&initialize_vectors();
&setup_data($input_file);

&print_user_profile;

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
    my $num_links = 0;

    while( defined ( $link = <INPUT_FILE>) ) {
        $num_links++;
        # We access each of the links one at a time...
        chomp $link;

        my $page_html = &retreive_webpage($link);
        
        if ( $page_html eq 0 ) {
            print LOG "Could Not Retreive The HTML for $link\n";
            next;
        }

        &process_recipie_website($page_html);

    }

    #NORMALIZE THE USER_VECTOR BY THE NUMBER OF FILES

    while (($term,$weight) = each %user_profile) {
        $user_profile{$term} = $weight / $num_links;
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

    $url = shift;

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

    return $response->content;

}

######################################
# PROCESS_RECIPIE_WEBSITE
#
# Handles extraction of the webpage
# Execution of HTTP requests
#
########################################

sub process_recipie_website {
    $html_text = shift;

    $parser = HTML::TokeParser->new( \$html_text );

    while (my $token = $parser->get_token) {
        @array = @{ $token };
        if ($array[0] eq 'T') {
            my @words = split( /\s+/, $array[1] );
            $last_word = "UNCOMMON_TEXT"; #This should always fail on the first try...
            foreach $word ( @words ) {
                $word = lc( $word );
                if (defined ($foodwords{$word} )) {
                    
                    if ( defined ( $user_profile{$word} )) {
                        $user_profile{$word} = $user_profile{$word} + 1;
                    }
                    else {
                        $user_profile{$word} =  1;
                    }

                }

                $bigram = "$last_word $word";
                if (defined ($foodwords{$bigram} )) {
                    
                    if ( defined ( $user_profile{$bigram} ) ) {
                        $user_profile{$bigram} = $user_profile{$bigram} + 1;
                    }
                    else {
                        $user_profile{$bigram} =  1;
                    }

                }
                #elsif (defined ($foodverbs{$word} ) ) {

                #    if ( defined ( $user_profile{$word} )) {
                #        $user_profile{$word} = $user_profile{$word} + 1;
                #    }
                #    else {
                #        $user_profile{$word} =  1;
                #    }

                #}
                $last_word = $word;
            }
        }
    }

    #&print_user_profile;

}


########################################################
##  PRINT_VEC
##
##  A simple debugging tool. Prints the contents of a 
##  given document or query vector. Note that the order
##  in which the terms are enumerated is arbitrary.
########################################################

sub print_user_profile {

  while (($term,$weight) = each %user_profile) {
    printf("TERM = %10s \t WEIGHT = %s\n",$term,$weight); 
  }
}