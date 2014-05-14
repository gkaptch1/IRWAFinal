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
%web_profile = ();
%scores = ();

URI::URL::strict( 1 ); 

my $log_file = shift (@ARGV);
my $input_file = shift (@ARGV);
my $output_file = shift (@ARGV);
if ((!defined ($log_file)) || (!defined ($input_file)) || (!defined ($output_file))) {
    print STDERR "You must specify a log file, a content file and a base_url\n";
    print STDERR "when running the web robot:\n";
    print STDERR "  ./robot_base.pl mylogfile.log content.txt base_url\n";
    exit (1);
}

$| = 1;

open LOG, '>', "$log_file";
open OUTPUT, '>', "$output_file";

my $ROBOT_NAME = 'KaptchukChandlerFoodBot/1.0';
my $ROBOT_MAIL = 'gkaptch1@jhu.edu';

my $robot = new LWP::RobotUA $ROBOT_NAME, $ROBOT_MAIL;
$robot->delay( .01 );

my $base_url    = "";#shift(@ARGV);   

&initialize_vectors();
&setup_data($input_file);

$base_url = &find_start();
print LOG "Starting Point is $base_url";

&print_user_profile;

push @search_urls, $base_url;
$pushed{ $base_url } = 1;

print LOG "BEGIN CRAWLING\n";
print LOG "--------------------------------------\n";
################################################
#
#               BEGIN CRAWLER
#
################################################
while (@search_urls) {
    my $url = shift @search_urls;
    #print "Relevance Of Next URL: " . $relevance{$url} . "\n";
    #print "Length Of search_urls: " . scalar( @search_urls ) . "\n";

    #print "\n" . $url . ":\n";

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

    #Update Scores
    $score = &cosine_sim();
    
    foreach my $link (@related_urls) {
        my $full_url ="";
        $full_url = eval { (new URI::URL $link, $response->base)->abs; };
        if(defined $full_url) {
            if ($full_url =~ '#') {
                my @temp = split ('#', $full_url);
                $full_url = $temp[0];
            }
                
            delete $relevance{ $link } and next if $@;

            $relevance{ $full_url } = $relevance{ $link } *  $score ;
            delete $relevance{ $link } if $full_url ne $link;

            $scores{$full_url} = $score;

            chomp $full_url;


            if ( (!exists $pushed{ $full_url })) {
                 push @search_urls, $full_url;
                 $pushed{ $full_url } = 1;
                 $relevance{ $full_url } = $score;  
            }
        }
        
    }

    

    #printf("URL = %s \t SCORE = %s\n",$url,$score); 
    
    #print  "URL = $url \t SCORE = $score\n";
    print OUTPUT "$url\n" if ($score ge .0005);
    
    #
    # reorder the urls base upon relevance so that we search
    # areas which seem most relevant to us first.
    #

    @search_urls = 
    sort { $scores{ $b } <=> $scores{ $a } } @search_urls;

}

close LOG;
close OUTPUT;
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

        &setup_user_profile($page_html);

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
# EXTRACT_CONTENT
#
# Handles extraction of the webpage
# Execution of HTTP requests
#
########################################
sub extract_content {
    my $content = shift;
    my $url = shift;

    chomp $url;

    my $page_html = $content;
        
    if ( $page_html eq 0 ) {
        print LOG "Could Not Retreive The HTML for $url\n";
        next;
    }
    &process_recipie_website($page_html);

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
            (undef, $two, $three, $four) = split('\/', $link);
            if(defined $four) {
               if($three=~ /recipes/) {
                if($four =~ /recipes/) {
                    #print "$link\n";
                    $relevance{ $link } = 1;
                    $urls{ $link }      = 1;    
                }
            }
            }
            if(defined $two) {
                if ($two =~ /Recipe/) {
                    $link = "http://allrecipes.com" . $link;
                    #print "$link\n";
                    $relevance{ $link } = 1;
                    $urls{ $link }      = 1;
                }
            }
            
        }
    }

    return keys %urls;   # the keys of the associative array hold all the
                         # links we've found (no repeats).
}

######################################
# PROCESS_RECIPIE_WEBSITE
#
# Handles extraction of the webpage
# Execution of HTTP requests
#
########################################

sub setup_user_profile {
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

                $last_word = $word;
            }
        }
    }

    #&print_user_profile;

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

    %web_profile = ();

    $parser = HTML::TokeParser->new( \$html_text );

    while (my $token = $parser->get_token) {
        @array = @{ $token };
        if ($array[0] eq 'T') {
            my @words = split( /\s+/, $array[1] );
            $last_word = "UNCOMMON_TEXT"; #This should always fail on the first try...
            foreach $word ( @words ) {
                $word = lc( $word );
                if (defined ($foodwords{$word} )) {
                    
                    if ( defined ( $web_profile{$word} )) {
                        $web_profile{$word} = $web_profile{$word} + 1;
                    }
                    else {
                        $web_profile{$word} =  1;
                    }

                }

                $bigram = "$last_word $word";
                if (defined ($foodwords{$bigram} )) {
                    
                    if ( defined ( $web_profile{$bigram} ) ) {
                        $web_profile{$bigram} = $web_profile{$bigram} + 1;
                    }
                    else {
                        $web_profile{$bigram} =  1;
                    }

                }

                $last_word = $word;
            }
        }
    }

    #&print_user_profile;

}

########################################################
##  COSINE_SIM
##
##  Calculated the cosine similarity for the current web 
##  page and the user profile.  Returns score
########################################################

sub cosine_sim {
  $num=0; $sumsq1=0; $sumsq2=0;

  while (($term1,$weight1) = each %user_profile) {
    $num += defined $web_profile{ $term1 } ? ( $weight1 * $web_profile{$term1} ) : 0;
    $sumsq1 += ( $weight1 * $weight1 );
  }

  while (($term2,$weight2) = each %web_profile) {
    $sumsq2 += ( $weight2 * $weight2 );
  }

  return ( $num / ( sqrt($sumsq1*$sumsq2) ) );

}

########################################################
##  FIND_START
##
##  
########################################################

sub find_start {

    $user_profile{ 'aspx' } = -10000;

    my $allrec = "./recipehubs.xml";
    my $best_starting_place = "http://allrecipes.com/recipes/healthy-recipes/main-dishes/"; #default, because why not.
    my $best_link_score = 0;

    open(ALL_RECIPES,$allrec) || die "Can't open $allrec: $!\n";
 
    while( defined ($line = <ALL_RECIPES>) ) {

        %link_profile = ();
        chomp $line;
        next if $line =~ m/daily/;
        if ( $line =~ /<loc>/) {
            @parts = split (/[<>]/, $line);
            $url = $parts[2];
            #print "$url\n";
            chomp $url;

            #we now compute the similarity of the user profile and each link profile
            @words = split(/[\.-\/]/ , $url);


            foreach $word ( @words ) {
                $word = lc( $word );
                if (defined ($foodwords{$word} )) {
                    
                    if ( defined ( $link_profile{$word} )) {
                        $link_profile{$word} = $link_profile{$word} + 1;
                    }
                    else {
                        $link_profile{$word} =  1;
                    }
                }
            }

            $num = 0;

            while (($term1,$weight1) = each %user_profile) {
               $num += defined $link_profile{ $term1 } ? ( $weight1 * $link_profile{$term1} ) : 0;
             }

             #my $scr = sqrt($sumsq1*$sumsq2) != 0? $num / ( sqrt($sumsq1*$sumsq2) ) : 0 ;

             #print "$scr\n";

             if ($num ge $best_link_score) {
                $best_link_score = $num;
                $best_starting_place = $url;
             }

        }
    }

    close ALL_RECIPES;

    return $best_starting_place;


}

########################################################
##  PRINT_USER_PROFLE
##
##  FOR DEBUGGING
########################################################

sub print_user_profile {

  while (($term,$weight) = each %user_profile) {
    printf("TERM = %10s \t WEIGHT = %s\n",$term,$weight); 
  }
}

########################################################
##  PRINT_SCORES
##
##  FOR DEBUGGING
########################################################

sub print_scores {

  while (($term,$weight) = each %scores) {
    printf("URL = %s \t SCORE = %s\n",$term,$weight); 
  }
}