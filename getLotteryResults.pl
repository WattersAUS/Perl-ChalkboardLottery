#!/usr/bin/perl -w
#
#	Program: updateLotteryResults.pl (2016-11-21) G.J.Watson
#
#	Purpose: download / parse / store results from the lottery games
#
#	Date		Version		Note
#	==========	=======		==================================================
#	2016-11-21	v0.01		First cut of code
#	2016-11-27	v0.02		First attempt at basic functionality
#	2016-11-28	v0.03		Moved logger write to sqlBuffer
#	2016-11-30	v0.04		Added a WorkSpace directory for file processing
#	2016-12-04	v0.05		Inserts/Update code in place
#	2016-12-05	v0.06		Fixed regrex for date extraction
#	2016-12-05	v1.00		Release version
#	2016-12-06	v1.01		Moved msg in extractFromArray to end of func
#                           Rewrote processSQLBuffer
#                           Rewrote processLotteryDraws
#	2016-12-21	v1.02		Incorrectly reporting array size in extractFromArray
#

use lib "/var/sites/s/shiny-ideas.tech/bin/Classes";

use strict;
use vars qw($opt_d $opt_h $opt_i $opt_t $opt_w);
use Getopt::Std;
use DBI;
use File::Basename;

#-----------------------------------------------------------------------------
# ok here's the db objects to access
#-----------------------------------------------------------------------------

use Lottery::draw_history;
use Lottery::logger;
use Lottery::lottery_draws;
use Lottery::number_usage;

#-----------------------------------------------------------------------------
# only globals in the whole program (I hope)
#-----------------------------------------------------------------------------

my $version_id = "1.02";

#-----------------------------------------------------------------------------
# this holds sql statements batched up (bit like a transaction for each line)
#-----------------------------------------------------------------------------

my @sqlBuffer = qw();

#-----------------------------------------------------------------------------
# this holds the messages to be mailed to Shiny Ideas
#-----------------------------------------------------------------------------

my @mail_buffer = qw();

#-----------------------------------------------------------------------------
# special DEBUG message for help function
#-----------------------------------------------------------------------------

sub debugHelpMessage {
    my $debugMsg = shift;
    if (defined($debugMsg)) {
        print $debugMsg;
    }
    print "\n";
    return;
}

#-----------------------------------------------------------------------------
# log messages to the database and to stdout via debugMessage
#-----------------------------------------------------------------------------

sub logMessage {
    my $ident   = shift;
    my $message = shift;
    debugMessage($message);
    buildLogger($ident, $message);
    return;
}

#-----------------------------------------------------------------------------
# print out DEBUG messages allowing for possible date/time stamp inclusion
#-----------------------------------------------------------------------------

sub debugMessage {
    my $debugMsg = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    if ($opt_t) {
		printf "[ %4d-%02d-%02d %02d:%02d:%02d ] ", $year+1900,$mon+1,$mday,$hour,$min,$sec;
    }
    print "DEBUG: ";
    if (defined($debugMsg)) {
        print $debugMsg;
    }
    print "\n";
    return;
}

#-----------------------------------------------------------------------------
# write to logger table
#-----------------------------------------------------------------------------

sub buildLogger {
    my $ident    = shift;
	my $message  = shift;
	my $logger   = new logger;
    $logger->ident($ident);
	$logger->description($message);
	$logger->last_modified("now()");
	$logger->CreateINSERT;
	debugMessage($logger->{SQL_STATEMENT}->[0]);
    push(@sqlBuffer, $logger->{SQL_STATEMENT}->[0]);
	return;
}

#-----------------------------------------------------------------------------
# break out and execute the 'wget' to retrieve the page containing results
#  wget https://url -O filename.txt
#-----------------------------------------------------------------------------

sub getResultsPage {
    my $url  = shift;
    my $file = shift;

    # remove the file in case we has already downloaded it
    if (-e $file) {
        unlink($file);
    }

    # go get it!
    my @args = ("wget", $url, "-O", $file);
    system(@args) == 0
        or die "system() call to execute 'wget' failed with status ".$?;
    return;
}

#-----------------------------------------------------------------------------
# load the file into an array we can easily parse when we need
#-----------------------------------------------------------------------------

sub loadResultsIntoArray {
    my $file  = shift;
    # load the file into an array where we parse through multiple times
    my @fileContents = qw();
    open(INPUT, "< ".$file)
        or die "Cannot results page ".$file." $!\n";
    while (my $input_line = <INPUT>) {
        push(@fileContents, $input_line);
    }
    close(INPUT);
    return @fileContents;
}

#-----------------------------------------------------------------------------
# parse the array stripping out the numbers or specials
#-----------------------------------------------------------------------------

sub extractFromArray {
    my $ident   = shift;
    my $numbers = shift;
    my $tag     = shift;
    my @data    = @_;
    my @extracted = qw();
    foreach my $line (@data) {
        if ($line =~ m/$tag/) {
            $line =~ s/.*$tag//;
            $line =~ tr/0-9//cd;
            push(@extracted, $line);
        }
    }
    logMessage($ident, "Searched for tag (".$tag.") in results page and extracted (".$#extracted + 1.") numbers...");
    return (@extracted);
}

#-----------------------------------------------------------------------------
# parse the array to extract the data string
#
# Fri 25 Nov 2016 for eg
#-----------------------------------------------------------------------------

sub convertMonthToInteger {
    my $mth = shift;
    my %month = (
        'Jan' => '01',
        'Feb' => '02',
        'Mar' => '03',
        'Apr' => '04',
        'May' => '05',
        'Jun' => '06',
        'Jul' => '07',
        'Aug' => '08',
        'Sep' => '09',
        'Oct' => '10',
        'Nov' => '11',
        'Dec' => '12'
        );
    return $month{$mth};
}

sub decodeDayMonthYear {
    my $dateStr = shift;
    my $day   = 1;
    my $month = 1;
    my $year  = 1;
    my @nums  = $dateStr =~ /(\d+)/g;
    if ($#nums > 0) {
        $day   = $nums[0];
        $year  = $nums[1];
        $month =  $dateStr;
        $month =~ s/$year//;
        $month =~ s/.*$day//;
        $month =~ s/\s//g;
        $month = convertMonthToInteger($month);
    }
    return ($day, $month, $year);
}

sub extractDayMonthYearFromArray {
    my @data = @_;

    foreach my $line (@data) {
        if ($line =~ m/<h1>[MTWTFS][ouehra][neduit].*20[12][1-9]<\/h1>/) {
            $line =~ s/^[ \t]*//;
            $line =~ s/<[\/]{0,1}h1>//g;
            $line =~ s/\n//g;
            $line =~ s/\r//g;
            return decodeDayMonthYear($line);
        }
    }
    return (1, 1, 1);
}

#-----------------------------------------------------------------------------
# check the numbers / specials we extracted are valid
#
# right number of results
# within range
#-----------------------------------------------------------------------------

sub checkNumbersWithinLimits {
    my $ident   = shift;
    my $numbers = shift;
    my $upper   = shift;
    my $type    = shift;
    my @array   = @_;
    my $passed  = 1;

    # have we got the right number of values
    if ($numbers != ($#array + 1)) {
        logMessage($ident, "ERROR: Loaded ".($#array + 1)." ".$type."s this does not match the expected value of ".$numbers."...");
        $passed = 0;
    }

    # are they within range
    foreach my $num (@array) {
        if (($num < 1) || ($num > $upper)) {
            logMessage($ident, "ERROR: The ".$type." ".$num." is not within the expected range of values 1 to ".$upper."...");
            $passed = 0;
        }
    }
    logMessage($ident, "Found ".$numbers." expected (".$type.") within range 1 to ".$upper."...");
    return $passed;
}

#-----------------------------------------------------------------------------
# store 'number_usage'
#-----------------------------------------------------------------------------

sub buildNewNumberUsage {
    my $ident       = shift;
	my $draw        = shift;
	my $number      = shift;
	my $isSpecial   = shift;
	my $numberUsage = new number_usage;
    $numberUsage->ident($ident);
	$numberUsage->draw($draw);
	$numberUsage->number($number);
	$numberUsage->is_special($isSpecial);
	$numberUsage->CreateINSERT;
    debugMessage($numberUsage->{SQL_STATEMENT}->[0]);
	push(@sqlBuffer, $numberUsage->{SQL_STATEMENT}->[0]);
	return;
}

sub storeNumberUsage {
    my $ident   = shift;
    my $draw    = shift;
    my $special = shift;
    my @array   = @_;
    foreach my $num (@array) {
        buildNewNumberUsage($ident, $draw, $num, $special);
    }
    return;
}

#-----------------------------------------------------------------------------
# store 'draw_history'
#-----------------------------------------------------------------------------

sub buildNewDrawHistory {
    my $ident       = shift;
	my $draw        = shift;
	my $drawDate    = shift;
	my $drawHistory = new draw_history;
    $drawHistory->ident($ident);
	$drawHistory->draw($draw);
	$drawHistory->draw_date($drawDate);
    $drawHistory->last_modified("now()");
	$drawHistory->CreateINSERT;
    debugMessage($drawHistory->{SQL_STATEMENT}->[0]);
	push(@sqlBuffer, $drawHistory->{SQL_STATEMENT}->[0]);
	return;
}

sub storeDrawHistory {
    my $ident   = shift;
    my $draw    = shift;
    my $dateStr = shift;
    buildNewDrawHistory($ident, $draw, $dateStr);
    return;
}

#-----------------------------------------------------------------------------
# we should now have an array full of SQL commands to apply to the DB
# if we don't have any ACTIVITY records then don't apply any
#
# after use make sure we zap it
#-----------------------------------------------------------------------------

sub processLotteryDraws {
    my $dbHandle = shift;
    my $wrkSpace = shift;

    # iterate through configured lottery draws, we will get the 'next' draw
    # as we expect to already have the draw set in the db
    my $draws = new lottery_draws;
    $draws->ResetKEYFIELDS;
    $draws->DataSAVE;
    $draws->CreateSELECT;
    debugMessage($draws->{SQL_STATEMENT}->[0]);
    my $sth = $dbHandle->prepare($draws->{SQL_STATEMENT}->[0]);
    $sth->execute;
    while (my @fields = $sth->fetchrow) {
        $draws->DataINITIALISE(@fields);
        $draws->DataSAVE;
        my $identifier   = $draws->{ident}->[0];
        my $description  = $draws->{description}->[0];
        my $draw         = $draws->{draw}->[0];
        my $base_url     = $draws->{base_url}->[0];
        my $numbers      = $draws->{numbers}->[0];
        my $upperNumber  = $draws->{upper_number}->[0];
        my $numbersTag   = $draws->{numbers_tag}->[0];
        my $specials     = $draws->{specials}->[0];
        my $upperSpecial = $draws->{upper_special}->[0];
        my $specialsTag  = $draws->{specials_tag}->[0];

        # now we need to prep settings to get the page for the next draw, using the url and filename
        $draw++;
        my $filename     = lc($description);
        $filename        =~ s/\s/_/g;
        $filename        .= ".".$draw;
        my $url          = $base_url;
        $url             =~ s/DRAWNUMBER/$draw/g;

        # get the results page itself
        logMessage($identifier, "Ready to get Lottery results for (".$draws->{description}->[0]."), draw (".$draw."), into file (".$filename."), using url (".$url.")");
        my $downloadFile = $wrkSpace."/".$filename;
        getResultsPage($url, $downloadFile);

        # check we got a file, extract the numbers / specials / date and validate
        if (! -e $downloadFile) {
            logMessage($identifier, "ERROR: Unable to find file (".$downloadFile.") to process...\n");
        } else {
            my @data = loadResultsIntoArray($downloadFile);
            logMessage($identifier, "Loaded results page, ".$#data." lines into an array for processing...");
            my @resultNumbers = extractFromArray($identifier, $numbers,  $numbersTag, @data);
            if (($#resultNumbers + 1) == 0) {
                logMessage($identifier, "Detected no numbers in the results page, abandoning upload...");
            } else {
                # make sure we pass all checks before we decide to store the values
                if (checkNumbersWithinLimits($identifier, $numbers, $upperNumber, "number", @resultNumbers) == 1) {
                    my @specialNumbers = extractFromArray($identifier, $specials, $specialsTag, @data);
                    if (checkNumbersWithinLimits($identifier, $specials, $upperSpecial, "special", @specialNumbers) == 1) {
                        my ($day, $month, $year) = extractDayMonthYearFromArray(@data);
                        # now we're ready to store...
                        #
                        # 1. draw numbers
                        # 2. any special numbers
                        # 3. update the draw details
                        #
                        storeNumberUsage($identifier, $draw, 0, @resultNumbers);
                        if (($#specialNumbers + 1) > 0) {
                            storeNumberUsage($identifier, $draw, 1, @specialNumbers);
                        }
                        storeDrawHistory($identifier, $draw, $year."-".$month."-".$day);
                        $draws->ResetKEYFIELDS;
                        $draws->SetKEYFIELDS("ident");
                        $draws->draw($draw);
                        $draws->last_modified("now()");
                        $draws->CreateUPDATE;
                        $draws->CreateCONDITION;
                        debugMessage($draws->{SQL_STATEMENT}->[0]);
                        push(@sqlBuffer, $draws->{SQL_STATEMENT}->[0]);
                        processSQLBuffer($dbHandle);
                    }
                }
            }
        }
    }
    $sth->finish;
    return;
}

#-----------------------------------------------------------------------------
# we should now have an array full of SQL commands to apply to the DB
#
# after use make sure we zap it
#-----------------------------------------------------------------------------

sub processSQLBuffer {
	my $dbHandle = shift;
    if ($opt_i) {
        debugMessage("Applying SQL Statements to database...");
        foreach my $sql_statement (@sqlBuffer) {
    			my $sth = $dbHandle->prepare($sql_statement);
    			$sth->execute;
    	}
    } else {
        debugMessage("Database writes are disabled...");
    }
	@sqlBuffer = qw();
	return;
}

#-----------------------------------------------------------------------------
# db connection vars / command line params
#-----------------------------------------------------------------------------

my $db   = "";
my $user = "";
my $pass = "";
my $host = "";

my $wrksp = "./";

#-----------------------------------------------------------------------------
# check for any command line params and set appropriately
#-----------------------------------------------------------------------------

getopts('dhitw:');

# help screen
if (defined($opt_h)) {
	debugHelpMessage("\n\tLottery Data Upload Utility ".$version_id);
	debugHelpMessage("\t================================");
	debugHelpMessage( "\t-i (Activate Writing to DB)");
	debugHelpMessage( "\t-h (view this HELP Mode)");
	debugHelpMessage( "\t-d (turn on DEBUG Mode)");
	debugHelpMessage( "\t-t (turn on date/time stamp on DEBUG messages)");
    debugHelpMessage( "\t-w <DIR>         (workspace directory to use)\n");
	exit(0);
}

# date/time stamp on DEBUG messages
if (defined($opt_t)) {
	debugMessage("Date/Time Stamp Active");
} else {
    debugMessage("Date/Time Stamp Inactive");
}

# work directory
if (defined($opt_w)) {
	$wrksp = $opt_w;
}
debugMessage(" Work Space: ".$wrksp);

#-----------------------------------------------------------------------------
# main code
#-----------------------------------------------------------------------------

my $dbHandle = DBI->connect("DBI:mysql:".$db.":".$host, $user, $pass);
if (! $dbHandle) {
    debugMessage("Can't get access to the database\n");
} else {

    # opened the db successfully, so now we can process the draws
    debugMessage("Querying database for draws to process...");
    processLotteryDraws($dbHandle, $wrksp);

    # done, close the db and get out of here!
    $dbHandle->disconnect();
    debugMessage("Closed database connection...");
}

debugMessage("End of line...");

# End of Line.....
